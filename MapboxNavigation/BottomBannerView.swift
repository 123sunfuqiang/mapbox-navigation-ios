import UIKit
import MapboxCoreNavigation
import MapboxDirections

protocol BottomBannerViewDelegate: class {
    func didCancel()
}

/// :nodoc:
@IBDesignable
@objc(MBBottomBannerView)
open class BottomBannerView: UIView, NavigationComponent {
    
    weak var previousProgress: RouteProgress?
    var timer: DispatchTimer?
    
    weak var timeRemainingLabel: TimeRemainingLabel!
    weak var distanceRemainingLabel: DistanceRemainingLabel!
    weak var arrivalTimeLabel: ArrivalTimeLabel!
    weak var cancelButton: CancelButton!
    // Vertical divider between cancel button and the labels
    weak var verticalDividerView: SeparatorView!
    // Horizontal divider between the map view and the bottom banner
    weak var horizontalDividerView: SeparatorView!
    weak var delegate: BottomBannerViewDelegate?
    
    let dateFormatter = DateFormatter()
    let dateComponentsFormatter = DateComponentsFormatter()
    let distanceFormatter = DistanceFormatter(approximate: true)
    
    var verticalCompactConstraints = [NSLayoutConstraint]()
    var verticalRegularConstraints = [NSLayoutConstraint]()
    
    var congestionLevel: CongestionLevel = .unknown {
        didSet {
            switch congestionLevel {
            case .unknown:
                timeRemainingLabel.textColor = timeRemainingLabel.trafficUnknownColor
            case .low:
                timeRemainingLabel.textColor = timeRemainingLabel.trafficLowColor
            case .moderate:
                timeRemainingLabel.textColor = timeRemainingLabel.trafficModerateColor
            case .heavy:
                timeRemainingLabel.textColor = timeRemainingLabel.trafficHeavyColor
            case .severe:
                timeRemainingLabel.textColor = timeRemainingLabel.trafficSevereColor
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    deinit {
        removeTimer()
    }
    
    override open func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        if superview != nil, newSuperview == nil {
            removeTimer()
        }
    }
    
    private func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(removeTimer), name: .UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetETATimer), name: .UIApplicationWillEnterForeground, object: nil)
    }
    
    private func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidEnterBackground, object: nil)
    }
    
    func commonInit() {
        dateFormatter.timeStyle = .short
        dateComponentsFormatter.allowedUnits = [.hour, .minute]
        dateComponentsFormatter.unitsStyle = .abbreviated
        
        setupViews()
        
        cancelButton.addTarget(self, action: #selector(BottomBannerView.cancel(_:)), for: .touchUpInside)
    }
    
    @IBAction func cancel(_ sender: Any) {
        delegate?.didCancel()
    }
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        timeRemainingLabel.text = "22 min"
        distanceRemainingLabel.text = "4 mi"
        arrivalTimeLabel.text = "10:09"
    }
    
    @objc public func navigationService(_ service: NavigationService, didRerouteAlong route: Route, at location: CLLocation?, proactive: Bool) {
        refreshETA()
    }
    
    @objc public func navigationService(_ service: NavigationService, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        resetETATimer()
        updateETA(routeProgress: progress)
        previousProgress = progress
    }
    
    @objc func removeTimer() {
        timer?.disarm()
        timer = nil
    }
    
    @objc func resetETATimer() {
        removeTimer()
        timer = MapboxCoreNavigation.DispatchTimer(countdown: .seconds(30), repeating: .seconds(30)) { [weak self] in
            self?.refreshETA()
        }
        timer?.arm()
    }
    
    @objc func refreshETA() {
        guard let progress = previousProgress else { return }
        updateETA(routeProgress: progress)
    }
    
    func updateETA(routeProgress: RouteProgress) {
        guard let arrivalDate = NSCalendar.current.date(byAdding: .second, value: Int(routeProgress.durationRemaining), to: Date()) else { return }
        arrivalTimeLabel.text = dateFormatter.string(from: arrivalDate)

        if routeProgress.durationRemaining < 5 {
            distanceRemainingLabel.text = nil
        } else {
            distanceRemainingLabel.text = distanceFormatter.string(from: routeProgress.distanceRemaining)
        }

        dateComponentsFormatter.unitsStyle = routeProgress.durationRemaining < 3600 ? .short : .abbreviated

        if let hardcodedTime = dateComponentsFormatter.string(from: 61), routeProgress.durationRemaining < 60 {
            timeRemainingLabel.text = String.localizedStringWithFormat(NSLocalizedString("LESS_THAN", bundle: .mapboxNavigation, value: "<%@", comment: "Format string for a short distance or time less than a minimum threshold; 1 = duration remaining"), hardcodedTime)
        } else {
            timeRemainingLabel.text = dateComponentsFormatter.string(from: routeProgress.durationRemaining)
        }
        
        guard let congestionForRemainingLeg = routeProgress.averageCongestionLevelRemainingOnLeg else { return }
        congestionLevel = congestionForRemainingLeg
    }
}
