//
//  EditorScrollView.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2015-01-15.
//
//  ---------------------------------------------------------------------------
//
//  © 2015-2018 1024jp
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

final class EditorScrollView: NSScrollView {
    
    // MARK: Lifecycle
    
    deinit {
        self.documentView?.removeObserver(self, forKeyPath: #keyPath(NSTextView.layoutOrientation))
    }
    
    
    
    // MARK: Scroll View Methods
    
    /// use custom ruler view
    override class var rulerViewClass: AnyClass! {
        
        get {
            return LineNumberView.self
        }
        
        set {
            super.rulerViewClass = LineNumberView.self
        }
    }
    
    
    /// set text view
    override var documentView: NSView? {

        willSet {
            guard let textView = newValue as? NSTextView else { return }

            // -> DO NOT use block-based KVO for NSTextView sublcass
            //    since it causes application crash on OS X 10.11 (but ok on macOS 10.12 and later 2018-02)
            textView.addObserver(self, forKeyPath: #keyPath(NSTextView.layoutOrientation), options: .initial, context: nil)
        }
    }
    
    
    /// observed key value did update
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == #keyPath(NSTextView.layoutOrientation) {
            switch self.layoutOrientation {
            case .horizontal:
                self.hasVerticalRuler = true
                self.hasHorizontalRuler = false
            case .vertical:
                self.hasVerticalRuler = false
                self.hasHorizontalRuler = true
            }
            
            // invalidate line number view background
            self.window?.viewsNeedDisplay = true
        }
    }
    
    
    
    // MARK: Public Methods
    
    func invalidateLineNumber() {
        
        self.lineNumberView?.needsDisplay = true
        self.lineNumberView?.needsLayout = true
    }
    
    override func reflectScrolledClipView(_ cView: NSClipView) {
        
        super.reflectScrolledClipView(cView)
        
        self.lineNumberView?.needsLayout = true
    }
    
    
    
    // MARK: Private Methods
    
    /// return layout orientation of document text view
    private var layoutOrientation: NSLayoutManager.TextLayoutOrientation {
        
        guard let documentView = self.documentView as? NSTextView else {
            return .horizontal
        }
        
        return documentView.layoutOrientation
    }
    
    
    /// return current line number view
    private var lineNumberView: NSRulerView? {
    
        switch self.layoutOrientation {
        case .horizontal:
            return self.verticalRulerView
            
        case .vertical:
            return self.horizontalRulerView
        }
    }
    
}
