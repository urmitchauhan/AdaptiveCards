import AdaptiveCards_bridge
import AppKit

class ImageRenderer: NSObject, BaseCardElementRendererProtocol {
    static let shared = ImageRenderer()
    
    func render(element: ACSBaseCardElement, with hostConfig: ACSHostConfig, style: ACSContainerStyle, rootView: ACRView, parentView: NSView, inputs: [BaseInputHandler], config: RenderConfig) -> NSView {
        guard let imageElement = element as? ACSImage else {
            logError("ImageRenderer -> Element is not of type ACSImage")
            return NSView()
        }
                        
        guard let url = imageElement.getUrl() else {
            logError("ImageRenderer -> URL is not available")
            return NSView()
        }
        logInfo("ImageRenderer -> init")
        let imageView: ImageView
        if let dimensions = rootView.getImageDimensions(for: url) {
            let image = NSImage(size: dimensions)
            imageView = ImageView(image: image)
        } else {
            imageView = ImageView()
        }
        
        rootView.registerImageHandlingView(imageView, for: url)
      
        let imageProperties = ACRImageProperties(element: imageElement, config: hostConfig, parentView: parentView)
        let cgsize = imageProperties.contentSize

        // Setting up ImageView based on Image Properties
        imageView.wantsLayer = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer?.masksToBounds = true
        
        if imageProperties.isAspectRatioNeeded {
            // when either width or height px is available
            // this will provide content aspect fill scaling
            imageView.imageScaling = .scaleProportionallyUpOrDown
        } else {
            // content aspect fit behaviour
            imageView.imageScaling = .scaleAxesIndependently
        }
        
        // Setting up content holder view
        let wrappingView = ACRImageWrappingView(imageProperties: imageProperties, imageView: imageView)
        wrappingView.translatesAutoresizingMaskIntoConstraints = false
    
        // Background color attribute
        if let backgroundColor = imageElement.getBackgroundColor(), !backgroundColor.isEmpty {
            imageView.wantsLayer = true
            if let color = ColorUtils.color(from: backgroundColor) {
                imageView.layer?.backgroundColor = color.cgColor
            }
        }
        
        switch imageProperties.acsHorizontalAlignment {
        case .center: imageView.centerXAnchor.constraint(equalTo: wrappingView.centerXAnchor).isActive = true
        case .right: imageView.trailingAnchor.constraint(equalTo: wrappingView.trailingAnchor).isActive = true
        default: imageView.leadingAnchor.constraint(equalTo: wrappingView.leadingAnchor).isActive = true
        }
        
        wrappingView.heightAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true

        if !imageProperties.hasExplicitDimensions {
            if imageProperties.acsImageSize == ACSImageSize.stretch {
                wrappingView.widthAnchor.constraint(equalTo: imageView.widthAnchor).isActive = true
            } else {
                wrappingView.widthAnchor.constraint(greaterThanOrEqualTo: imageView.widthAnchor).isActive = true
            }
        } else {
            if cgsize.width > 0 {
                wrappingView.widthAnchor.constraint(greaterThanOrEqualTo: imageView.widthAnchor).isActive = true
            }
        }
    
        let imagePriority = NSLayoutConstraint.Priority.defaultHigh
        if imageProperties.acsImageSize != ACSImageSize.stretch {
            imageView.setContentHuggingPriority(imagePriority, for: .horizontal)
            imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
            imageView.setContentCompressionResistancePriority(imagePriority, for: .horizontal)
            imageView.setContentCompressionResistancePriority(imagePriority, for: .vertical)
        }
        
        if imageView.image != nil {
            configUpdateForImage(image: imageView.image, imageView: imageView)
        }
         
        if imageElement.getStyle() == .person {
            wrappingView.isPersonStyle = true
        }
        
        wrappingView.setupSelectAction(imageElement.getSelectAction(), rootView: rootView)
        wrappingView.setupSelectActionAccessibility(on: wrappingView, for: imageElement.getSelectAction())
        
        return wrappingView
    }
    
    func configUpdateForImage(image: NSImage?, imageView: NSImageView) {
        guard let superView = imageView.superview as? ACRImageWrappingView, let imageSize = image?.absoluteSize else {
            logError("ImageRenderer -> superView or image is nil")
            return
        }
        
        guard let imageProperties = superView.imageProperties else {
            logError("ImageRenderer -> imageProperties is null")
            return
        }
        imageProperties.updateContentSize(size: imageSize)
        let cgSize = imageProperties.contentSize
        superView.isImageSet = true
        
        let priority = NSLayoutConstraint.Priority.defaultHigh
        
        var constraints: [NSLayoutConstraint] = []
        
        constraints.append(imageView.widthAnchor.constraint(equalToConstant: cgSize.width))
        constraints.append(imageView.heightAnchor.constraint(equalToConstant: cgSize.height))
        constraints[0].priority = priority
        constraints[1].priority = priority
        
        guard cgSize.width > 0, cgSize.height > 0 else { return }
        
        if !imageProperties.hasExplicitDimensions {
            constraints.append(imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: cgSize.width / cgSize.height, constant: 0))
            constraints.append(imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: cgSize.height / cgSize.width, constant: 0))
        }
        
        NSLayoutConstraint.activate(constraints)
                    
        superView.invalidateIntrinsicContentSize()
    }
}

class ImageView: NSImageView, ImageHoldingView {
    override var intrinsicContentSize: NSSize {
        guard let image = image else {
            return .zero
        }
        return image.absoluteSize
    }
    func setImage(_ image: NSImage) {
        if self.image == nil {
            // update constraints only when image view does not contain an image
            ImageRenderer.shared.configUpdateForImage(image: image, imageView: self)
        }
        self.image = image
    }
}
