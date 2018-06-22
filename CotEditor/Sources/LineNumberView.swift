//
//  LineNumberView.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by nakamuxu on 2005-03-30.
//
//  ---------------------------------------------------------------------------
//
//  © 2004-2007 nakamuxu
//  © 2014-2018 1024jp
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa
import CoreText

final class LineNumberView: NSRulerView {
    
    class ColorFillView: NSView {
        
        override init(frame: NSRect) {
            
            super.init(frame: frame)
        }
        
        required init?(coder decoder: NSCoder) {
            
            super.init(coder: decoder)
        }
        
        
        // MARK: View Properties
        
        override var wantsUpdateLayer: Bool {
            
            return true
        }
        
        override var isOpaque: Bool {
            
            return (fillColor.alphaComponent == 1.0)
        }
        
        
        // MARK: Properties
        
        public var fillColor = NSColor.black
        {
            didSet {
                
                if (self.fillColor != oldValue) {
                    self.needsDisplay = true
                }
            }
        }
        
        override func updateLayer() {
            
            super.updateLayer()
            
            guard let layer = self.layer else {
                return
            }
            
            layer.backgroundColor = fillColor.cgColor
        }
        
    }
    
    // MARK: -
    // MARK: Accessory View Classes
    
    final class WrappedMarkView: ColorFillView {}
    
    final class TickView: ColorFillView {}
    
    final class NumberView: NSView {
        
        public override init(frame frameRect: NSRect) {
            
            super.init(frame: frameRect)
            self.wantsLayer = true
        }
        public required init?(coder decoder: NSCoder) {
            
            super.init(coder: decoder)
        }
        
        
        private static let fontSizeFactor: CGFloat = 0.9
        private static let lineNumberFont: CGFont = LineNumberFont.regular.cgFont
        private static let boldLineNumberFont: CGFont = LineNumberFont.bold.cgFont
        
        struct DrawingInfo: Equatable {
            
            init(textFont: NSFont, scale: CGFloat) {

                self.textFont = textFont
                self.scale = scale
                
                // setup font
                let textFontSize = scale * textFont.pointSize
                self.fontSize = min(round(NumberView.fontSizeFactor * textFontSize), textFontSize)
                
                let ctFont = CTFontCreateWithGraphicsFont(NumberView.lineNumberFont, fontSize, nil, nil)
                let font = (ctFont as NSFont)
                
                // prepare glyphs
                self.wrappedMarkGlyph = ctFont.glyph(for: "-".utf16.first!)
                self.digitGlyphs = (0...9).map { ctFont.glyph(for: String($0).utf16.first!) }
                
                // calculate character width assuming the font is monospace
                self.charWidth = ctFont.advance(for: digitGlyphs[8]).width
                self.height = ceil(font.ascender - font.descender + font.leading)
                
                self.alignmentRectInsets = NSEdgeInsets(
                    top: ceil(font.pointSize - font.ascender),
                    left: 0.0,
                    bottom: ceil(-font.descender),
                    right: 0.0
                )
                
                self.font = font
                self.ctFont = ctFont
            }
            
            func isSameSource(textFont: NSFont, scale: CGFloat) -> Bool {
                
                return (self.textFont == textFont) && (self.scale == scale)
            }
            
            static public func ==(lhs: DrawingInfo, rhs: DrawingInfo) -> Bool {
                
                return lhs.isSameSource(textFont: rhs.textFont, scale: rhs.scale)
            }
            
            
            // MARK: Source Properties
            
            let textFont: NSFont
            let scale: CGFloat
            
            
            // MARK: Calculated Properties
            
            let ctFont: CTFont
            let font: NSFont
            let fontSize: CGFloat
            let digitGlyphs: [CGGlyph]
            let wrappedMarkGlyph: CGGlyph
            let charWidth: CGFloat
            let height: CGFloat
            let alignmentRectInsets: NSEdgeInsets
            
        }
        
        
        public var lineNumber: Int = 321 {
            
            didSet {
                if (oldValue != self.lineNumber) {
                    self.needsDisplay = true
                    self.invalidateIntrinsicContentSize()
                }
            }
        }
        
        public var isSelected: Bool = false {
           
            didSet {
                if (oldValue != self.isSelected) {
                    self.needsDisplay = true
                }
            }
        }
        
        public var drawingInfo: DrawingInfo? {
            
            didSet {
                if (oldValue != self.drawingInfo) {
                    self.needsDisplay = true
                    self.invalidateIntrinsicContentSize()
                }
            }
        }
        
        public var textColor: NSColor? {
            
            didSet {
                if (oldValue != self.textColor) {
                    self.needsDisplay = true
                }
            }
        }
        
        public var opaqueBackgroundColor: NSColor? {
            
            didSet {
                if (self.opaqueBackgroundColor != oldValue) {
                    self.needsDisplay = true
                }
            }
        }
        
        /// return text color considering current accesibility setting
        private func foregroundColor(_ strength: ColorStrength = .normal) -> NSColor {
            
            let textColor = self.textColor ?? .textColor
            
            if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast, strength != .stroke {
                return textColor
            }
            
            return textColor.withAlphaComponent(strength.rawValue)
        }
        
        
        // MARK: Layout
        
        override var intrinsicContentSize: NSSize {

            guard let drawingInfo = self.drawingInfo else {
                return .zero
            }
            return NSSize(
                width: ceil(CGFloat(self.lineNumber.numberOfDigits) * drawingInfo.charWidth),
                height: drawingInfo.font.pointSize
            )
        }
        override var alignmentRectInsets: NSEdgeInsets {
            
            return (self.drawingInfo?.alignmentRectInsets ?? .init())
        }
        
        
        // MARK: Drawing
        
        override var isOpaque: Bool {
            
            return (self.opaqueBackgroundColor != nil)
        }
        
        override func draw(_ dirtyRect: NSRect) {

            guard let drawingInfo = self.drawingInfo, let context = NSGraphicsContext.current?.cgContext else {
                NSColor.red.setFill()
                dirtyRect.fill()
                return
            }
            
            context.saveGState()
            defer { context.restoreGState() }
            
            // fill opaque background
            if let opaqueBackgroundColor = self.opaqueBackgroundColor {
                opaqueBackgroundColor.setFill()
                dirtyRect.fill()
            }
            
            let digitCount = self.lineNumber.numberOfDigits
            
            // calculate base position
            let alignmentRectInsets = drawingInfo.alignmentRectInsets
            let basePosition = CGPoint(x: alignmentRectInsets.left, y: alignmentRectInsets.bottom)
            
            // get glyphs and positions
            let positions: [CGPoint] = (0..<digitCount)
                .map { basePosition.offsetBy(dx: (CGFloat($0) * drawingInfo.charWidth)) }
            let glyphs: [CGGlyph] = (0..<digitCount)
                .map { self.lineNumber.number(at: (digitCount - 1 - $0)) }
                .map { drawingInfo.digitGlyphs[$0] }
            
            // set font attributes
            context.setFontSize(drawingInfo.fontSize)
            
            if self.isSelected {
                context.setFillColor(self.foregroundColor(.bold).cgColor)
                context.setFont(NumberView.boldLineNumberFont)
            } else {
                context.setFillColor(self.foregroundColor().cgColor)
                context.setFont(NumberView.lineNumberFont)
            }
            
            context.textMatrix = .identity
            
            // disable subpixel rendering since we draw translucent text
            context.setShouldSmoothFonts(false)
            
            // draw
            context.showGlyphs(glyphs, at: positions)
        }
        
        
        // MARK: Animation
        
        public func bounce() {
            
            guard let layer = self.layer else {
                return
            }
            let bounceAnimation = CAKeyframeAnimation(keyPath: #keyPath(CALayer.transform) + ".scale.x")
            bounceAnimation.keyTimes = [0.0, 0.4, 1.0]
            bounceAnimation.values = [1.08, 1.2, 1.0].map { 1.0 + (($0 - 1.0) / Double(lineNumber.numberOfDigits)) }
            bounceAnimation.duration = 0.26
            bounceAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
            layer.add(bounceAnimation, forKey: "selected")
        }
        
        public func cancelBounce() {
            
            guard let layer = self.layer else {
                return
            }
            layer.removeAnimation(forKey: "selected")
        }
        
    }
    
    // MARK: Constants
    
    private let minNumberOfDigits = 3
    private let minVerticalThickness: CGFloat = 32.0
    private let minHorizontalThickness: CGFloat = 20.0
    private let lineNumberPadding: CGFloat = 4.0
    private let fontSizeFactor: CGFloat = 0.9
    
    private let lineNumberFont: CGFont = LineNumberFont.regular.cgFont
    private let boldLineNumberFont: CGFont = LineNumberFont.bold.cgFont
    
    private enum ColorStrength: CGFloat {
        case normal = 0.75
        case bold = 0.9
        case wrappedMark = 0.5
        case stroke = 0.2
    }
    
    
    // MARK: Private Properties
    
    private var requiredNumberOfDigits = 0
    
    private weak var draggingTimer: Timer?
    
    private let borderView = ColorFillView()
    
    static var CachedNumberViews: [NumberView] = []
    static var CachedWrappedMarkViews: [WrappedMarkView] = []
    static var CachedTickViews: [TickView] = []
    
    private var lastNumberDrawingInfo: NumberView.DrawingInfo?
    private var lineSeparatedString: LineSeparatedString?

    // MARK: -
    // MARK: Lifecycle
    
    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        
        super.init(scrollView: scrollView, orientation: orientation)
        
        // observe new textStorage change
        if let textView = scrollView?.documentView as? NSTextView {
            NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: NSText.didChangeNotification, object: textView)
            NotificationCenter.default.addObserver(self, selector: #selector(selectionDidChangeContinuous), name: EditorTextView.didChangeSelectionContinuousNotification, object: textView)
        }
        self.autoresizesSubviews = false
    }
    
    
    required init(coder: NSCoder) {
        
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: Layout
    
    override func layout() {
        
        if #available(macOS 10.12, *) {
            // "AppKit no longer requires calling [super layout]."
        } else {
            defer { super.layout() }
        }
        
        var bounds = self.bounds
        
        // layout border
        var borderFrame = bounds
        switch self.orientation {
        case .verticalRuler:
            borderFrame.size.width = 1.0
            borderFrame.origin.x += (bounds.width - borderFrame.width)
            
            borderView.autoresizingMask = [.minXMargin, .height]
        case .horizontalRuler:
            borderFrame.size.height = 1.0
            borderFrame.origin.y += (bounds.height - borderFrame.height)
            
            borderView.autoresizingMask = [.minYMargin, .width]
        }
        borderView.frame = borderFrame
        
        // prepare subviews
        var remainingOldSubviews = self.subviews
        let rulerViewSubviews = remainingOldSubviews.filter { !(($0 is NumberView) || ($0 is WrappedMarkView) || ($0 is TickView) || ($0 == borderView)) }
        var subviews: [NSView] = rulerViewSubviews + [borderView]
        
        // update actual subviews later
        defer {
            self.subviews = subviews
            
            // cache unused views
            let cacheMaxCount = 10
            
            LineNumberView.CachedNumberViews += remainingOldSubviews.compactMap{ (subviews.contains($0)) ? nil : ($0 as? NumberView) }
                .prefix(max(0, cacheMaxCount - LineNumberView.CachedNumberViews.count))
            
            LineNumberView.CachedWrappedMarkViews += remainingOldSubviews.compactMap{ (subviews.contains($0)) ? nil : ($0 as? WrappedMarkView) }
                .prefix(max(0, cacheMaxCount - LineNumberView.CachedWrappedMarkViews.count))
            
            LineNumberView.CachedTickViews += remainingOldSubviews.compactMap{ (subviews.contains($0)) ? nil : ($0 as? TickView) }
                .prefix(max(0, cacheMaxCount - LineNumberView.CachedTickViews.count))
            
            //moof(LineNumberView.CachedNumberViews.count, LineNumberView.CachedWrappedMarkViews.count, LineNumberView.CachedTickViews.count)
        }
        
        guard
            let textView = self.textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
            else { return }
        
        let lineSeparatedString: LineSeparatedString
        if let cachedLineSeparatedString = self.lineSeparatedString {
            lineSeparatedString = cachedLineSeparatedString
        } else {
            lineSeparatedString = LineSeparatedString(textView.string)
            self.lineSeparatedString = lineSeparatedString
        }
        
        let text = lineSeparatedString.string//textView.string
        let text_utf16 = text.utf16
        let textLength = (text as NSString).length
        let isVerticalText = self.orientation == .horizontalRuler
        let scale = textView.scale
        
        // this seems slow on large document
        //
        //if !lineSeparatedString.isSameSource(text) {
        //    lineSeparatedString = LineSeparatedString(text)
        //}
        
        // setup font
        let textFont = textView.font ?? NSFont.systemFont(ofSize: 0)
        let numberDrawingInfo: NumberView.DrawingInfo
        if let lastNumberDrawingInfo = self.lastNumberDrawingInfo, lastNumberDrawingInfo.isSameSource(textFont: textFont, scale: scale) {
            numberDrawingInfo = lastNumberDrawingInfo
        } else {
            numberDrawingInfo = NumberView.DrawingInfo(textFont: textFont, scale: scale)
            self.lastNumberDrawingInfo = numberDrawingInfo
        }
        
        // prepare frame width
        let lineNumberPadding = round(scale * self.lineNumberPadding)
        let tickLength = ceil(numberDrawingInfo.fontSize / 3)
        
        // adjust thickness
        var ruleThickness: CGFloat
        if isVerticalText {
            ruleThickness = max(numberDrawingInfo.fontSize + 2.5 * tickLength, self.minHorizontalThickness)
        } else {
            let numberOfLines = lineSeparatedString.numberOfLines
            self.requiredNumberOfDigits = max(numberOfLines.numberOfDigits, self.minNumberOfDigits)
            
            // use the line number of whole string, namely the possible largest line number
            // -> The view width depends on the number of digits of the total line numbers.
            //    It's quite dengerous to change width of line number view on scrolling dynamically.
            ruleThickness = max(CGFloat(self.requiredNumberOfDigits) * numberDrawingInfo.charWidth + 3 * lineNumberPadding, self.minVerticalThickness)
        }
        ruleThickness = ceil(ruleThickness)
        if ruleThickness != self.ruleThickness {
            self.ruleThickness = ruleThickness
        }
        
        let opaqueBackgroundColor = self.isOpaque ? self.backgroundColor : nil
        
        let scrolledOffset: CGFloat = {
            let relativePoint = self.convert(NSPoint.zero, from: textView)
            let inset = textView.textContainerOrigin.scaled(to: scale)
            return isVerticalText
                ? (relativePoint.x - inset.y - (scale * textFont.ascender))
                : (relativePoint.y + inset.y + (scale * (textFont.pointSize - textFont.ascender)))
        }()
        
        // get multiple selections
        let selectedCharacterRanges_ns = textView.selectedRanges.map { $0.rangeValue }
        let selectedCharacterRanges = selectedCharacterRanges_ns.compactMap { Range($0, in: text) }
        let selectedLines = selectedCharacterRanges.flatMap { (characterRange) -> [Int] in
            
            guard let min = lineSeparatedString.line(at: characterRange.lowerBound) else {
                guard (characterRange.lowerBound == text.endIndex), (lineSeparatedString.numberOfLines > 0) else {
                    return []
                }
                return [lineSeparatedString.numberOfLines - 1]
            }
            if (text.startIndex < characterRange.upperBound),
                (characterRange.lowerBound < characterRange.upperBound),
                let max = lineSeparatedString.line(at: text.index(before: characterRange.upperBound))
            {
                return [Int](min..<(max + 1))
            } else if let max = lineSeparatedString.line(at: characterRange.upperBound) {
                return [Int](min..<(max + 1))
            } else {
                return [min]
            }
        }
        let selectedLineCharacterRanges = selectedLines.compactMap { lineSeparatedString.characterRangeForLine($0) }
        let selectedLineCharacterRanges_ns: [NSRange] = selectedLineCharacterRanges.compactMap { NSRange($0, in: text) } //textView.selectedRanges.map { (text as NSString).lineRange(for: $0.rangeValue) }
        
        
        /// put line number blocks later
        var putNumberOperations: [()->Void] = []
        defer { putNumberOperations.forEach { $0() } }
        
        func putNumber(_ line: Int, y: CGFloat, isSelected: Bool) {
            
            let lineNumber = self.lineNumber(forLine: line)
            
            // to avoid unnecessary redraws, dequeue existing views with high priority
            var visibleView: NumberView?
            if let remainingIndex = remainingOldSubviews.index(where: {($0 as? NumberView)?.lineNumber == lineNumber}) {
                visibleView = remainingOldSubviews.remove(at: remainingIndex) as? NumberView
            }
            
            putNumberOperations.append {
                _putNumberActually(visibleView: visibleView, lineNumber: lineNumber, y: y, isSelected: isSelected)
            }
        }
        
        func _putNumberActually(visibleView: NumberView?, lineNumber: Int, y: CGFloat, isSelected: Bool) {
            
            let numberView: NumberView
            var wasVisibleAsSameNumber = false
            if let visibleView = visibleView {
                numberView = visibleView
                wasVisibleAsSameNumber = true
            } else if let reusedViewIndex = remainingOldSubviews.index(where: { $0 is NumberView }) {
                numberView = remainingOldSubviews.remove(at: reusedViewIndex) as! NumberView
            } else if let cachedNumberView = LineNumberView.CachedNumberViews.popLast() {
                numberView = cachedNumberView
            } else {
                numberView = NumberView()
                numberView.translatesAutoresizingMaskIntoConstraints = false
            }
            if !wasVisibleAsSameNumber {
                numberView.isSelected = false
                numberView.cancelBounce()
            }
            numberView.textColor = textView.textColor
            numberView.drawingInfo = numberDrawingInfo
            numberView.lineNumber = lineNumber
            numberView.opaqueBackgroundColor = opaqueBackgroundColor
            subviews.append(numberView)
            
            var numberFrame = NSRect(origin: .zero, size: numberView.intrinsicContentSize)
            if isVerticalText {
                numberFrame.origin.x = (scrolledOffset - y - (numberFrame.width * 0.5))
                numberFrame.origin.y = (1.0 * scale)
            } else {
                numberFrame.origin.x = (bounds.width - numberFrame.width - lineNumberPadding)
                numberFrame.origin.y = (scrolledOffset + y)
            }
            
            // consider alignmentRectInsets
            //   usually frame(forAlignmentRect:) does same job
            //   but when the view doesn't have superview,
            //   it returns a rect assuming that (superview.isFlipped == false).
            let alignmentRectInsets = numberView.alignmentRectInsets
            numberFrame.origin.x -= alignmentRectInsets.left
            numberFrame.origin.y -= alignmentRectInsets.top
            numberFrame.size.width += (alignmentRectInsets.left + alignmentRectInsets.right)
            numberFrame.size.height += (alignmentRectInsets.top + alignmentRectInsets.bottom)
            
            numberView.frame = self.centerScanRect(numberFrame)
            
            if wasVisibleAsSameNumber, isSelected, !numberView.isSelected, !isVerticalText {
                numberView.bounce()
            }
            numberView.isSelected = isSelected
        }
        
        /// put wrapped mark (-)
        func putWrappedMark(y: CGFloat, digitCount: Int) {
            
            let markView: WrappedMarkView
            if let remainingIndex = remainingOldSubviews.index(where: { $0 is WrappedMarkView }) {
                markView = remainingOldSubviews.remove(at: remainingIndex) as! WrappedMarkView
            } else if let cachedMarkView = LineNumberView.CachedWrappedMarkViews.popLast() {
                markView = cachedMarkView
            } else {
                markView = WrappedMarkView()
                markView.translatesAutoresizingMaskIntoConstraints = false
            }
            markView.fillColor = self.textColor(.wrappedMark)
            subviews.append(markView)
            
            let markRect: CGRect = {
                var rect = CGRect(origin: .zero, size: CGSize(width: (numberDrawingInfo.charWidth * CGFloat(digitCount)), height: 1))
                rect.origin.x = (bounds.width - rect.width - lineNumberPadding)
                rect.origin.y += (scrolledOffset + ((numberDrawingInfo.height - rect.height) * 0.5) + y)
                return rect
            }()
            markView.frame = self.centerScanRect(markRect)
        }
        
        /// put ticks block for vertical text
        func putTick(y: CGFloat) {
            
            let tickView: TickView
            if let remainingIndex = remainingOldSubviews.index(where: { $0 is TickView }) {
                tickView = remainingOldSubviews.remove(at: remainingIndex) as! TickView
            } else if let cachedTickView = LineNumberView.CachedTickViews.popLast() {
                tickView = cachedTickView
            } else {
                tickView = TickView()
                tickView.translatesAutoresizingMaskIntoConstraints = false
            }
            tickView.fillColor = self.textColor(.stroke)
            subviews.append(tickView)
            
            let tickRect: CGRect = {
                var rect = CGRect(origin: .zero, size: CGSize(width: 1, height: (tickLength - 1)))
                rect.origin.x = scrolledOffset
                rect.origin.x -= y
                rect.origin.y = (bounds.height - rect.height - 1)
                return rect
            }()
            tickView.frame = self.centerScanRect(tickRect)
        }
        
        // extend visible rect a bit to enable bottom line number animation
        let textViewVisibleRect = textView.visibleRect.insetBy(dx: 0, dy: (isVerticalText ? 0 : -30))
        
        // get glyph range of which line number should be drawn
        let glyphRangeToDraw: NSRange
        if isVerticalText {
            glyphRangeToDraw = layoutManager.glyphRange(forBoundingRect: textViewVisibleRect, in: textContainer)
        } else {
            glyphRangeToDraw = layoutManager.glyphRange(forBoundingRectWithoutAdditionalLayout: textViewVisibleRect, in: textContainer)
        }
        
        // count up lines until visible
        let firstVisibleIndex = layoutManager.characterIndexForGlyph(at: glyphRangeToDraw.location)
        var line = 0
        if (firstVisibleIndex < text_utf16.count) {
            line = lineSeparatedString.line(at: text_utf16.index(text_utf16.startIndex, offsetBy: firstVisibleIndex).samePosition(in: text)!) ?? 0
        }
        
        // draw visible line numbers
        var glyphIndex = glyphRangeToDraw.location
        var lastLine = -1
        
        while glyphIndex < glyphRangeToDraw.upperBound {  // count "real" lines
            defer {
                line += 1
            }
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            guard (charIndex < text_utf16.count), let characterIndex = text_utf16.index(text_utf16.startIndex, offsetBy: charIndex).samePosition(in: text), let lineRange = lineSeparatedString.lineRange(at: characterIndex) else {
                break
            }
            let lineRange_ns = NSRange(lineRange, in: text)
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineRange_ns, actualCharacterRange: nil)
            glyphIndex = lineGlyphRange.upperBound
            
            // check if line is selected
            let isSelected = selectedLineCharacterRanges_ns.contains { selectedRange in
                (selectedRange.contains(lineRange_ns.location) &&
                    (!isVerticalText || (lineRange_ns.location == selectedRange.location || lineRange_ns.upperBound == selectedRange.upperBound)))
            }
            
            var wrappedLineGlyphIndex = lineGlyphRange.location
            while wrappedLineGlyphIndex < glyphIndex {  // handle wrapped lines
                var range = NSRange.notFound
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: wrappedLineGlyphIndex, effectiveRange: &range, withoutAdditionalLayout: true)
                let y = scale * lineRect.minY
                let isWrappedLine = (lastLine == line)
                lastLine = line
                wrappedLineGlyphIndex = range.upperBound
                
                if isWrappedLine {
                    guard !isVerticalText else { continue }
                    
                    putWrappedMark(y: y, digitCount: lineNumber(forLine: line).numberOfDigits)
                    
                } else {  // new line
                    if isVerticalText {
                        putTick(y: y)
                    }
                    if self.showsLine(line, isVerticalText: isVerticalText, isSelected: isSelected) ||
                        (lineRange_ns.upperBound == textLength && layoutManager.extraLineFragmentTextContainer == nil)  // last line for vertical text
                    {
                        putNumber(line, y: y, isSelected: isSelected)
                    }
                }
            }
        }
        
        // draw the last "extra" line number
        let lineRect = layoutManager.extraLineFragmentUsedRect
        if !lineRect.isEmpty, lineRect.intersects(textViewVisibleRect) {
            if let line = lineSeparatedString.line(at: text_utf16.index(text_utf16.startIndex, offsetBy: textLength).samePosition(in: text)!),
                (line != lastLine)
            {
                let isSelected: Bool = {
                    guard let lastSelectedRange = selectedLineCharacterRanges_ns.last else { return false }
                    
                    return (lastSelectedRange.length == 0) && (textLength == lastSelectedRange.upperBound)
                }()
                let y = scale * lineRect.minY
                
                if isVerticalText {
                    putTick(y: y)
                }
                putNumber(line, y: y, isSelected: isSelected)
            }
        }
    }
    
    
    // MARK: Line Parameters
    
    func showsLine(_ line: Int, isVerticalText: Bool, isSelected: Bool) -> Bool {
        
        let lineNumber = self.lineNumber(forLine: line)
        return (!isVerticalText || (lineNumber % 5 == 0) || (lineNumber == 1) || isSelected)
    }
    
    func lineNumber(forLine line: Int) -> Int {
        
        return line + 1
    }
    
    
    // MARK: Drawing
    
    override var wantsUpdateLayer: Bool {
        
        return true
    }
    
    
    override var isOpaque: Bool {
        
        if textView?.drawsBackground ?? false {
            return true
        } else {
            return false
        }
    }
    
    
    override func updateLayer() {
        
        super.updateLayer()
        
        layer?.backgroundColor = backgroundColor.cgColor
        borderView.fillColor = textColor(.stroke)
    }
    
    
    // if draw(_:) is not overriden, system may add some content view even when (wantsUpdateLayer == true)
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    
    /// remove extra thickness
    override var requiredThickness: CGFloat {
        
        if self.orientation == .horizontalRuler {
            return self.ruleThickness
        }
        return max(self.minVerticalThickness, self.ruleThickness)
    }
    
    
    // MARK: Public Methods
    
    public func invalidateLineNumber() {
        
        self.needsDisplay = true
        self.needsLayout = true
        self.lineSeparatedString = nil
    }
    
    
    // MARK: Private Methods
    
    /// return client view casting to textView
    private var textView: NSTextView? {
        
        return self.scrollView?.documentView as? NSTextView
    }
    
    
    /// return text color considering current accesibility setting
    private func textColor(_ strength: ColorStrength = .normal) -> NSColor {
        
        let textColor = self.textView?.textColor ?? .textColor
        
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast, strength != .stroke {
            return textColor
        }
        
        if isOpaque, let opaqueTextColor = backgroundColor.blended(withFraction: strength.rawValue, of: textColor) {
            return opaqueTextColor
        } else {
            return textColor.withAlphaComponent(strength.rawValue)
        }
    }
    
    
    /// return coloring theme
    private var backgroundColor: NSColor {
        
        let isDarkBackground = (self.textView as? Themable)?.theme?.isDarkTheme ?? false
        
        if let textView = self.textView, textView.drawsBackground {
            let backgroundColor = textView.backgroundColor
            return (isDarkBackground ? backgroundColor.highlight(withLevel: 0.08) : backgroundColor.shadow(withLevel: 0.06)) ?? backgroundColor
        } else {
            return isDarkBackground ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.06)
        }
    }
    
    
    /// update total number of lines determining view thickness on holizontal text layout
    @objc private func textDidChange(_ notification: Notification) {
        
        self.lineSeparatedString = nil
    }
    
    
    /// update selected states of each number views
    @objc private func selectionDidChangeContinuous(_ notification: Notification) {
        
        self.needsLayout = true
    }
}



// MARK: Line Number Font

private enum LineNumberFont {
    
    case regular
    case bold
    
    
    
    var font: NSFont {
        
        return NSFont(name: self.fontName, size: 0) ?? self.systemFont
    }
    
    
    var cgFont: CGFont {
        
        return CTFontCopyGraphicsFont(self.font, nil)
    }
    
    
    /// name of the first candidate font
    private var fontName: String {
        
        switch self {
        case .regular:
            return "AvenirNextCondensed-Regular"
        case .bold:
            return "AvenirNextCondensed-DemiBold"
        }
    }
    
    
    /// system font for fallback
    private var systemFont: NSFont {
        
        return .monospacedDigitSystemFont(ofSize: 0, weight: self.weight)
    }
    
    
    /// font weight for system fonts
    private var weight: NSFont.Weight {
        
        switch self {
        case .regular:
            return .regular
        case .bold:
            return .semibold
        }
    }
    
}



// MARK: Private Helper Extensions

private extension Int {
    
    /// number of digits
    var numberOfDigits: Int {
        
        guard self > 0 else { return 1 }
        
        return Int(log10(Double(self))) + 1
    }
    
    
    /// number at the desired place
    func number(at place: Int) -> Int {
        
        return ((self % Int(pow(10, Double(place + 1)))) / Int(pow(10, Double(place))))
    }
    
}


private extension CTFont {
    
    func advance(for glyph: CGGlyph, orientation: CTFontOrientation = .horizontal) -> CGSize {
        
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(self, orientation, [glyph], &advance, 1)  // use '8' to get width
        return advance
    }
    
    
    func glyph(for uniChar: UniChar) -> CGGlyph {
        
        var glyph = CGGlyph()
        CTFontGetGlyphsForCharacters(self, [uniChar], &glyph, 1)
        return glyph
    }
    
}


// MARK: - Line Selecting

private struct DraggingInfo {
    
    let index: Int
    let selectedRanges: [NSRange]
}


extension LineNumberView {
    
    // MARK: View Methods
    
    /// start selecting correspondent lines in text view with drag / click event
    override func mouseDown(with event: NSEvent) {
        
        guard
            let window = self.window,
            let textView = self.textView
            else { return }
        
        // get start point
        let point = window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
        let index = textView.characterIndex(for: point)
        
        // repeat while dragging
        self.draggingTimer = .scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(selectLines),
                                             userInfo: DraggingInfo(index: index, selectedRanges: textView.selectedRanges as! [NSRange]),
                                             repeats: true)
        
        self.selectLines(nil)  // for single click event
    }
    
    
    /// end selecting correspondent lines in text view with drag event
    override func mouseUp(with event: NSEvent) {
        
        self.draggingTimer?.invalidate()
        
        // settle selection
        //   -> in `selectLines:`, `stillSelecting` flag is always YES
        if let ranges = self.textView?.selectedRanges {
            self.textView?.selectedRanges = ranges
        }
    }
    
    
    
    // MARK: Private Methods
    
    /// select lines while dragging event
    @objc private func selectLines(_ timer: Timer?) {
        
        guard
            let window = self.window,
            let textView = self.textView
            else { return }
        
        let string = textView.string as NSString
        let draggingInfo = timer?.userInfo as? DraggingInfo
        let point = NSEvent.mouseLocation  // screen based point
        
        // scroll text view if needed
        let pointedRect = window.convertFromScreen(NSRect(origin: point, size: .zero))
        let targetRect = textView.convert(pointedRect, from: nil)
        textView.scrollToVisible(targetRect)
        
        // select lines
        let currentIndex = textView.characterIndex(for: point)
        let clickedIndex = draggingInfo?.index ?? currentIndex
        let currentLineRange = string.lineRange(at: currentIndex)
        let clickedLineRange = string.lineRange(at: clickedIndex)
        var range = currentLineRange.union(clickedLineRange)
        
        let affinity: NSSelectionAffinity = (currentIndex < clickedIndex) ? .upstream : .downstream
        
        // with Command key (add selection)
        if NSEvent.modifierFlags.contains(.command) {
            let originalSelectedRanges = draggingInfo?.selectedRanges ?? textView.selectedRanges as! [NSRange]
            var selectedRanges = [NSRange]()
            var intersects = false
            
            for selectedRange in originalSelectedRanges {
                if selectedRange.location <= range.location, range.upperBound <= selectedRange.upperBound {  // exclude
                    let range1 = NSRange(selectedRange.location..<range.location)
                    let range2 = NSRange(range.upperBound..<selectedRange.upperBound)
                    
                    if range1.length > 0 {
                        selectedRanges.append(range1)
                    }
                    if range2.length > 0 {
                        selectedRanges.append(range2)
                    }
                    
                    intersects = true
                    continue
                }
                
                // add
                selectedRanges.append(selectedRange)
            }
            
            if !intersects {  // add current dragging selection
                selectedRanges.append(range)
            }
            
            textView.setSelectedRanges(selectedRanges as [NSValue], affinity: affinity, stillSelecting: false)
            
            return
        }
        
        // with Shift key (expand selection)
        if NSEvent.modifierFlags.contains(.shift) {
            let selectedRange = textView.selectedRange
            if selectedRange.contains(currentIndex) {  // reduce
                let inUpperSelection = (currentIndex - selectedRange.location) < selectedRange.length / 2
                if inUpperSelection {  // clicked upper half section of selected range
                    range = NSRange(currentIndex..<selectedRange.upperBound)
                } else {
                    range = selectedRange
                    range.length -= selectedRange.upperBound - currentLineRange.upperBound
                }
            } else {  // expand
                range.formUnion(selectedRange)
            }
        }
        
        textView.setSelectedRange(range, affinity: affinity, stillSelecting: false)
    }
    
}

public class LineSeparatedString {
    
    public init(_ string: String) {
        
        self.string = string.immutable
    }

    
    // MARK: Public Properties
    
    public let string: String
    
    
    public lazy var includesLastLineEnding: Bool = {
        if (_includesLastLineEnding == nil) {
            self.processAndStoreValues()
        }
        return _includesLastLineEnding!
    }()
    
    
    public lazy var numberOfLines = self.lineBreakLocations.count
    
    
    // MARK: Process
    
    public lazy var lineBreakLocations: [String.Index] = {
        if (_lineBreakLocations == nil) {
            self.processAndStoreValues()
        }
        return _lineBreakLocations!
    }()
    private var _includesLastLineEnding: Bool?
    private var _lineBreakLocations: [String.Index]?
    
    
    private func processAndStoreValues() {
        
        let string = self.string
        guard !string.isEmpty, case let characterRange = string.startIndex..<string.endIndex else {
            self._lineBreakLocations = [string.startIndex]
            self._includesLastLineEnding = false
            return
        }
        
        var lineBreakLocations: [String.Index] = []
        
        string.enumerateSubstrings(in: characterRange, options: [.byLines, .substringNotRequired]) { (_, _, enclosingRange, _) in
            lineBreakLocations.append(string.index(before: enclosingRange.upperBound))
        }
        
        if let last = string.unicodeScalars.last, CharacterSet.newlines.contains(last) {
            lineBreakLocations.append(string.unicodeScalars.endIndex)
            self._includesLastLineEnding = true
        } else {
            self._includesLastLineEnding = false
        }
        self._lineBreakLocations = lineBreakLocations
    }
    
    
    // MARK: Public Methods

    public func isSameSource(_ string: String) -> Bool {
        
        return (self.string.hashValue == string.hashValue)
    }

    
    public func characterRangeForLine(_ line: Int) -> Range<String.Index>? {
        
        let string = self.string
        let lineBreakLocations = self.lineBreakLocations
        if string.isEmpty, (line == 0) {
            return string.startIndex..<string.endIndex
        }
        guard line < lineBreakLocations.count else {
            return nil
        }
        
        var lower: String.Index
        var upper: String.Index
        
        if (line > 0) {
            lower = string.index(after: lineBreakLocations[line - 1])
        } else {
            lower = string.startIndex
        }
        upper = (lineBreakLocations[line] < string.endIndex) ? string.index(after: lineBreakLocations[line]) : lineBreakLocations[line]
        
        return lower..<upper
    }
    
    
    public func lineRange(at location: String.Index) -> Range<String.Index>? {
        
        let string = self.string
        let lineBreakLocations = self.lineBreakLocations
        guard !string.isEmpty else {
            return nil
        }
        
        var lower: String.Index
        var upper: String.Index
        
        let currentLineEndIndex = lineBreakLocations.indexWithBinarySearch(for: location)
        guard (currentLineEndIndex < lineBreakLocations.count) else {
            return nil
        }
        if (currentLineEndIndex > 0) {
            lower = string.index(after: lineBreakLocations[currentLineEndIndex - 1])
        } else {
            lower = string.startIndex
        }
        upper = string.index(after: lineBreakLocations[currentLineEndIndex])
        
        return lower..<upper
    }
    

    public func line(at characterIndex: String.Index) -> Int? {
        
        let lineBreakLocations = self.lineBreakLocations
        let a = lineBreakLocations.indexWithBinarySearch(for: characterIndex)
        guard (a < lineBreakLocations.count) else {
            return nil
        }
        return a
    }
    
}

enum BinarySearchDirection {
    
    case lowerBound
    case upperBound
}
extension Array {
    
    func indexWithBinarySearch(direction: BinarySearchDirection = .lowerBound, handler: (_ other: Element)->Bool) -> Int {
        
        var okIndex: Int
        var ngIndex: Int
        
        switch direction {
        case .lowerBound:
            okIndex = self.count
            ngIndex = -1
        case .upperBound:
            okIndex = 0
            ngIndex = self.count
        }
        
        while (abs(okIndex - ngIndex) > 1) {
            let midIndex = ((okIndex + ngIndex) / 2)
            if handler(self[midIndex]) {
                okIndex = midIndex
            } else {
                ngIndex = midIndex
            }
        }
        return okIndex
    }
}

extension Array where Element: Comparable {
    
    func indexWithBinarySearch(for target: Element) -> Int {
        
        return self.indexWithBinarySearch(direction: .lowerBound) { (target <= $0) }
    }
    
}
