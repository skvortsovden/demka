import MultipeerConnectivity

final class ClickerSession: NSObject {
    static let serviceType = "demka-cl"

    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var mcSession: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var targetSessionId = ""

    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onCommand: ((String) -> Void)?

    var connectedPeerName: String? { mcSession?.connectedPeers.first?.displayName }

    // MARK: - Host (presenter side — advertises, waits for clicker)
    func startHosting(sessionId: String) {
        stopAll()
        targetSessionId = sessionId
        let s = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        mcSession = s
        let a = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["sid": sessionId], serviceType: Self.serviceType)
        a.delegate = self
        a.startAdvertisingPeer()
        advertiser = a
    }

    // MARK: - Clicker side (browses, finds host by session ID, sends commands)
    func startBrowsing(sessionId: String) {
        stopAll()
        targetSessionId = sessionId
        let s = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        mcSession = s
        let b = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        b.delegate = self
        b.startBrowsingForPeers()
        browser = b
    }

    func stopAll() {
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        browser?.stopBrowsingForPeers(); browser = nil
        mcSession?.disconnect(); mcSession = nil
    }

    func send(_ command: String) {
        guard let s = mcSession, !s.connectedPeers.isEmpty,
              let data = command.data(using: .utf8) else { return }
        try? s.send(data, toPeers: s.connectedPeers, with: .reliable)
    }
}

// MARK: - MCSessionDelegate
extension ClickerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:    self.onConnected?()
            case .notConnected: self.onDisconnected?()
            default: break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let cmd = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async { self.onCommand?(cmd) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension ClickerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, mcSession)
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[ClickerSession] advertiser failed: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension ClickerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard info?["sid"] == targetSessionId, let s = mcSession else { return }
        browser.invitePeer(peerID, to: s, withContext: nil, timeout: 10)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("[ClickerSession] browser failed: \(error)")
    }
}
