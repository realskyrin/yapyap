import Foundation
import Compression
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "ASRClient")

class ASRClient {
    var onTextUpdate: ((String) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private let settings = SettingsStore.shared
    private var seq: Int32 = 1
    private var isDisconnecting = false

    // Binary protocol constants (matching Python reference)
    private static let protocolVersion: UInt8 = 0b0001
    private static let headerSizeValue: UInt8 = 0b0001

    // Message types
    private static let msgTypeFullClientRequest: UInt8 = 0b0001
    private static let msgTypeAudioOnly: UInt8 = 0b0010
    private static let msgTypeServerResponse: UInt8 = 0b1001
    private static let msgTypeServerError: UInt8 = 0b1111

    // Flags
    private static let flagNoSequence: UInt8 = 0b0000
    private static let flagPosSequence: UInt8 = 0b0001
    private static let flagNegSequence: UInt8 = 0b0010
    private static let flagNegWithSequence: UInt8 = 0b0011

    func connect() {
        seq = 1
        isDisconnecting = false

        guard let url = URL(string: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async") else {
            logger.error("Invalid WebSocket URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue(settings.appKey, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(settings.accessKey, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue(settings.resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        let connectId = UUID().uuidString
        request.setValue(connectId, forHTTPHeaderField: "X-Api-Request-Id")

        logger.info("Connecting: resourceId=\(self.settings.resourceId), connectId=\(connectId)")
        logger.info("AppKey=\(self.settings.appKey.prefix(4))..., AccessKey=\(self.settings.accessKey.prefix(4))...")

        session = URLSession(configuration: .default)
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()

        sendFullClientRequest()
        receiveLoop()
    }

    func disconnect() {
        isDisconnecting = true
        logger.info("Disconnecting")
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: - Send

    func sendAudio(data: Data) {
        let packet = buildAudioPacket(data: data, isLast: false)
        webSocketTask?.send(.data(packet)) { error in
            if let error { logger.error("Send audio error: \(error.localizedDescription)") }
        }
    }

    func sendLastAudio() {
        let packet = buildAudioPacket(data: Data(), isLast: true)
        logger.info("Sending last audio packet (seq=\(-self.seq))")
        webSocketTask?.send(.data(packet)) { error in
            if let error { logger.error("Send last audio error: \(error.localizedDescription)") }
        }
    }

    private func sendFullClientRequest() {
        let payload: [String: Any] = [
            "user": [
                "uid": "yapyap_user"
            ],
            "audio": [
                "format": "pcm",
                "rate": 16000,
                "bits": 16,
                "channel": 1,
                "codec": "raw"
            ],
            "request": [
                "model_name": "bigmodel",
                "enable_itn": true,
                "enable_punc": true,
                "enable_ddc": true,
                "show_utterances": true,
                "enable_nonstream": true,
                "result_type": "full"
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            logger.error("Failed to serialize JSON payload")
            return
        }
        logger.debug("Full client request JSON (\(jsonData.count) bytes): \(String(data: jsonData, encoding: .utf8) ?? "?")")

        guard let gzipped = Self.gzipCompress(data: jsonData) else {
            logger.error("Failed to gzip payload")
            return
        }
        logger.debug("Gzipped payload: \(gzipped.count) bytes")

        // header(4) + seq(4) + payload_size(4) + payload
        let header = Self.buildHeader(
            messageType: Self.msgTypeFullClientRequest,
            flags: Self.flagPosSequence,
            serialization: 0x1, // JSON
            compression: 0x1   // Gzip
        )

        var packet = Data()
        packet.append(contentsOf: header)
        var seqBE = seq.bigEndian
        packet.append(Data(bytes: &seqBE, count: 4))
        logger.info("Sending full client request (seq=\(self.seq))")
        seq += 1
        var size = UInt32(gzipped.count).bigEndian
        packet.append(Data(bytes: &size, count: 4))
        packet.append(gzipped)

        logger.debug("Packet: \(packet.count) bytes, header=\(header.map { String(format: "%02x", $0) }.joined())")

        webSocketTask?.send(.data(packet)) { error in
            if let error {
                logger.error("Send full client request error: \(error.localizedDescription)")
            } else {
                logger.info("Full client request sent successfully")
            }
        }
    }

    private func buildAudioPacket(data: Data, isLast: Bool) -> Data {
        let gzipped = Self.gzipCompress(data: data) ?? data

        let flags: UInt8
        let packetSeq: Int32
        if isLast {
            flags = Self.flagNegWithSequence  // 0b0011
            packetSeq = -seq
        } else {
            flags = Self.flagPosSequence      // 0b0001
            packetSeq = seq
            seq += 1
        }

        let header = Self.buildHeader(
            messageType: Self.msgTypeAudioOnly,
            flags: flags,
            serialization: 0x0,
            compression: 0x1
        )

        var packet = Data()
        packet.append(contentsOf: header)
        var seqBE = packetSeq.bigEndian
        packet.append(Data(bytes: &seqBE, count: 4))
        var size = UInt32(gzipped.count).bigEndian
        packet.append(Data(bytes: &size, count: 4))
        packet.append(gzipped)
        return packet
    }

    private static func buildHeader(messageType: UInt8, flags: UInt8, serialization: UInt8, compression: UInt8) -> [UInt8] {
        let byte0 = (protocolVersion << 4) | headerSizeValue
        let byte1 = (messageType << 4) | flags
        let byte2 = (serialization << 4) | compression
        let byte3: UInt8 = 0x00
        return [byte0, byte1, byte2, byte3]
    }

    // MARK: - Receive

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    logger.debug("Received binary: \(data.count) bytes, raw=\(data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
                    self.parseResponse(data)
                case .string(let text):
                    logger.warning("Received unexpected text: \(text)")
                @unknown default:
                    break
                }
                self.receiveLoop()

            case .failure(let error):
                if !self.isDisconnecting {
                    logger.error("WebSocket receive error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func parseResponse(_ data: Data) {
        guard data.count >= 4 else {
            logger.error("Response too short: \(data.count) bytes")
            return
        }

        let headerSizeVal = Int(data[0] & 0x0F)
        let messageType = (data[1] >> 4) & 0x0F
        let flags = data[1] & 0x0F
        let serialization = (data[2] >> 4) & 0x0F
        let compression = data[2] & 0x0F

        logger.debug("Response: msgType=\(messageType), flags=\(flags), ser=\(serialization), comp=\(compression), headerSize=\(headerSizeVal)")

        if messageType == Self.msgTypeServerError {
            parseErrorResponse(data, headerSize: headerSizeVal, flags: flags)
            return
        }

        guard messageType == Self.msgTypeServerResponse else {
            logger.warning("Unknown message type: \(messageType)")
            return
        }

        var offset = headerSizeVal * 4

        if flags & 0x01 != 0 {
            if data.count >= offset + 4 {
                let respSeq = Int32(bigEndian: data[offset..<(offset+4)].withUnsafeBytes { $0.load(as: Int32.self) })
                logger.debug("Response sequence: \(respSeq)")
            }
            offset += 4
        }
        if flags & 0x02 != 0 {
            logger.debug("Last package flag set")
        }
        if flags & 0x04 != 0 {
            offset += 4
        }

        guard data.count >= offset + 4 else {
            logger.error("Response too short for payload size at offset \(offset)")
            return
        }
        let payloadSize = Int(UInt32(bigEndian: data[offset..<(offset+4)].withUnsafeBytes { $0.load(as: UInt32.self) }))
        offset += 4

        guard data.count >= offset + payloadSize else {
            logger.error("Response truncated: need \(offset + payloadSize), got \(data.count)")
            return
        }
        var payload = Data(data[offset..<(offset + payloadSize)])

        if compression == 0x1 {
            guard let decompressed = Self.gzipDecompress(data: payload) else {
                logger.error("Failed to decompress response payload (\(payloadSize) bytes)")
                return
            }
            payload = decompressed
        }

        if let jsonStr = String(data: payload, encoding: .utf8) {
            logger.debug("Response JSON: \(jsonStr.prefix(500))")
        }

        guard let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let resultList = json["result"] as? [String: Any],
              let text = resultList["text"] as? String else {
            logger.warning("Failed to parse result text from response")
            return
        }

        logger.info("ASR text: \(text)")
        DispatchQueue.main.async { [weak self] in
            self?.onTextUpdate?(text)
        }
    }

    private func parseErrorResponse(_ data: Data, headerSize: Int, flags: UInt8) {
        var offset = headerSize * 4

        if flags & 0x01 != 0 { offset += 4 }
        if flags & 0x04 != 0 { offset += 4 }

        guard data.count >= offset + 8 else {
            logger.error("Error response too short")
            return
        }
        let errorCode = Int32(bigEndian: data[offset..<(offset+4)].withUnsafeBytes { $0.load(as: Int32.self) })
        offset += 4
        let msgSize = Int(UInt32(bigEndian: data[offset..<(offset+4)].withUnsafeBytes { $0.load(as: UInt32.self) }))
        offset += 4

        var errorMsg = ""
        if data.count >= offset + msgSize, msgSize > 0 {
            errorMsg = String(data: data[offset..<(offset + msgSize)], encoding: .utf8) ?? ""
        }
        logger.error("ASR Server Error \(errorCode): \(errorMsg)")
    }

    // MARK: - Connection Test

    static func testConnection(
        appKey: String,
        accessKey: String,
        resourceId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        logger.info("[Test] ========== Connection Test Start ==========")
        logger.info("[Test] URL: https://openspeech.bytedance.com/api/v3/sauc/bigmodel_async")
        logger.info("[Test] X-Api-App-Key: \(appKey)")
        logger.info("[Test] X-Api-Access-Key: \(accessKey)")
        logger.info("[Test] X-Api-Resource-Id: \(resourceId)")
        let preCheckConnectId = UUID().uuidString
        logger.info("[Test] X-Api-Connect-Id: \(preCheckConnectId)")
        logger.info("[Test] ================================================")

        // Step 1: HTTP pre-check to get readable error from server
        guard let httpUrl = URL(string: "https://openspeech.bytedance.com/api/v3/sauc/bigmodel_async") else {
            completion(.failure(TestError("Invalid URL")))
            return
        }

        var httpReq = URLRequest(url: httpUrl)
        httpReq.setValue(appKey, forHTTPHeaderField: "X-Api-App-Key")
        httpReq.setValue(accessKey, forHTTPHeaderField: "X-Api-Access-Key")
        httpReq.setValue(resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        httpReq.setValue(preCheckConnectId, forHTTPHeaderField: "X-Api-Connect-Id")

        logger.info("[Test] Sending HTTP pre-check...")

        URLSession.shared.dataTask(with: httpReq) { data, response, error in
            if let data, let body = String(data: data, encoding: .utf8) {
                logger.info("[Test] HTTP pre-check body: \(body)")
            }
            if let httpResp = response as? HTTPURLResponse {
                logger.info("[Test] HTTP pre-check status: \(httpResp.statusCode)")
            }

            // Step 2: Now try actual WebSocket connection
            Self.doWebSocketTest(appKey: appKey, accessKey: accessKey, resourceId: resourceId, completion: completion)
        }.resume()
    }

    private static func doWebSocketTest(
        appKey: String,
        accessKey: String,
        resourceId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async") else {
            completion(.failure(TestError("Invalid URL")))
            return
        }

        var request = URLRequest(url: url)
        request.setValue(appKey, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(accessKey, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue(resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        let connectId = UUID().uuidString
        request.setValue(connectId, forHTTPHeaderField: "X-Api-Request-Id")
        logger.info("[Test] connectId=\(connectId)")

        let delegate = TestDelegate(completion: completion)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        delegate.task = task
        delegate.session = session
        task.resume()
        logger.info("[Test] WebSocket task resumed, waiting for handshake...")

        // Build full client request packet
        let payload: [String: Any] = [
            "user": ["uid": "yapyap_test"],
            "audio": ["format": "pcm", "rate": 16000, "bits": 16, "channel": 1, "codec": "raw"],
            "request": [
                "model_name": "bigmodel",
                "enable_itn": true,
                "enable_punc": true,
                "enable_ddc": true,
                "show_utterances": true,
                "enable_nonstream": true,
                "result_type": "full"
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            logger.error("[Test] Failed to serialize JSON")
            completion(.failure(TestError("Failed to serialize JSON")))
            session.invalidateAndCancel()
            return
        }
        logger.debug("[Test] JSON payload: \(String(data: jsonData, encoding: .utf8) ?? "?")")

        guard let gzipped = gzipCompress(data: jsonData) else {
            logger.error("[Test] Failed to gzip")
            completion(.failure(TestError("Failed to gzip payload")))
            session.invalidateAndCancel()
            return
        }
        logger.debug("[Test] Gzipped: \(gzipped.count) bytes")

        let header = buildHeader(
            messageType: msgTypeFullClientRequest,
            flags: flagPosSequence,
            serialization: 0x1,
            compression: 0x1
        )

        var packet = Data()
        packet.append(contentsOf: header)
        let seq: Int32 = 1
        var seqBE = seq.bigEndian
        packet.append(Data(bytes: &seqBE, count: 4))
        var size = UInt32(gzipped.count).bigEndian
        packet.append(Data(bytes: &size, count: 4))
        packet.append(gzipped)

        logger.info("[Test] Sending full client request: \(packet.count) bytes, header=\(header.map { String(format: "%02x", $0) }.joined())")

        task.send(.data(packet)) { error in
            if let error {
                let httpInfo = delegate.httpStatusInfo
                logger.error("[Test] Send failed: \(error.localizedDescription)\(httpInfo)")
                delegate.complete(with: .failure(TestError("Send failed\(httpInfo)\nDetail: \(error.localizedDescription)")))
                return
            }
            logger.info("[Test] Send succeeded, waiting for response...")

            task.receive { result in
                switch result {
                case .success(let message):
                    switch message {
                    case .data(let data):
                        logger.info("[Test] Received \(data.count) bytes: \(data.prefix(20).map { String(format: "%02x", $0) }.joined(separator: " "))")
                        guard data.count >= 4 else {
                            delegate.complete(with: .failure(TestError("Response too short (\(data.count) bytes)")))
                            return
                        }
                        let msgType = (data[1] >> 4) & 0x0F
                        let flags = data[1] & 0x0F
                        logger.info("[Test] msgType=\(msgType), flags=\(flags)")

                        if msgType == msgTypeServerError {
                            let headerSz = Int(data[0] & 0x0F) * 4
                            var off = headerSz
                            if flags & 0x01 != 0 { off += 4 }
                            if flags & 0x04 != 0 { off += 4 }
                            var errorCode: Int32 = 0
                            var errorMsg = ""
                            if data.count >= off + 4 {
                                errorCode = Int32(bigEndian: data[off..<(off+4)].withUnsafeBytes { $0.load(as: Int32.self) })
                                off += 4
                            }
                            if data.count >= off + 4 {
                                let msgSize = Int(UInt32(bigEndian: data[off..<(off+4)].withUnsafeBytes { $0.load(as: UInt32.self) }))
                                off += 4
                                if data.count >= off + msgSize, msgSize > 0 {
                                    errorMsg = String(data: data[off..<(off + msgSize)], encoding: .utf8) ?? "Unknown"
                                }
                            }
                            logger.error("[Test] Server error \(errorCode): \(errorMsg)")
                            delegate.complete(with: .failure(TestError("Server error \(errorCode): \(errorMsg)")))
                        } else if msgType == msgTypeServerResponse {
                            logger.info("[Test] Connection OK!")
                            delegate.complete(with: .success("Connection OK"))
                        } else {
                            logger.info("[Test] Unexpected msgType=\(msgType)")
                            delegate.complete(with: .success("Connected (msgType=\(msgType))"))
                        }
                    case .string(let text):
                        logger.info("[Test] Received text: \(text.prefix(200))")
                        delegate.complete(with: .success("Connected"))
                    @unknown default:
                        delegate.complete(with: .success("Connected"))
                    }
                case .failure(let error):
                    let httpInfo = delegate.httpStatusInfo
                    logger.error("[Test] Receive failed: \(error.localizedDescription)\(httpInfo)")
                    delegate.complete(with: .failure(TestError("Receive failed\(httpInfo)\nDetail: \(error.localizedDescription)")))
                }
            }
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            delegate.complete(with: .failure(TestError("Connection timed out (10s)")))
        }
    }

    struct TestError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    private class TestDelegate: NSObject, URLSessionWebSocketDelegate, URLSessionTaskDelegate {
        var task: URLSessionWebSocketTask?
        var session: URLSession?
        private let completion: (Result<String, Error>) -> Void
        private var completed = false
        private var httpStatusCode: Int?
        private var httpHeaders: [AnyHashable: Any]?

        init(completion: @escaping (Result<String, Error>) -> Void) {
            self.completion = completion
        }

        var httpStatusInfo: String {
            guard let code = httpStatusCode else { return "" }
            var info = "\nHTTP \(code)"
            if let headers = httpHeaders {
                for (key, value) in headers {
                    let k = "\(key)".lowercased()
                    if k.contains("error") || k.contains("reason") || k.contains("x-tt")
                        || k.contains("x-api") || k.contains("www-authenticate") {
                        info += "\n  \(key): \(value)"
                    }
                }
            }
            return info
        }

        func complete(with result: Result<String, Error>) {
            guard !completed else { return }
            completed = true
            task?.cancel(with: .normalClosure, reason: nil)
            session?.invalidateAndCancel()
            completion(result)
        }

        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                        didOpenWithProtocol protocol: String?) {
            logger.info("[Test] WebSocket handshake succeeded")
        }

        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
            let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
            logger.warning("[Test] WebSocket closed: code=\(closeCode.rawValue), reason=\(reasonStr)")
            if !completed {
                var msg = "WebSocket closed (code: \(closeCode.rawValue))"
                if let reason, let text = String(data: reason, encoding: .utf8) {
                    msg += "\nReason: \(text)"
                }
                complete(with: .failure(TestError(msg)))
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask,
                        didCompleteWithError error: Error?) {
            if let response = task.response as? HTTPURLResponse {
                httpStatusCode = response.statusCode
                httpHeaders = response.allHeaderFields
                logger.info("[Test] HTTP response: \(response.statusCode)")
                logger.debug("[Test] Response headers: \(response.allHeaderFields)")
            }
            if let error {
                logger.error("[Test] Task completed with error: \(error.localizedDescription)")
                if !completed {
                    let httpInfo = httpStatusInfo
                    complete(with: .failure(TestError("Connection failed\(httpInfo)\nDetail: \(error.localizedDescription)")))
                }
            }
        }
    }

    // MARK: - Compression

    static func gzipCompress(data: Data) -> Data? {
        if data.isEmpty {
            return Data([0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x13,
                         0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        }

        let bufferSize = data.count + data.count / 10 + 64
        var deflated = Data(count: bufferSize)

        let written = deflated.withUnsafeMutableBytes { destPtr -> Int in
            data.withUnsafeBytes { srcPtr -> Int in
                let dest = destPtr.bindMemory(to: UInt8.self)
                let src = srcPtr.bindMemory(to: UInt8.self)
                return compression_encode_buffer(
                    dest.baseAddress!, bufferSize,
                    src.baseAddress!, data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard written > 0 else {
            logger.error("DEFLATE compression failed")
            return nil
        }
        deflated.count = written

        var result = Data()
        result.append(contentsOf: [0x1f, 0x8b, 0x08, 0x00,
                                    0x00, 0x00, 0x00, 0x00,
                                    0x00, 0x03])
        result.append(deflated)
        var crc = crc32(data: data)
        result.append(Data(bytes: &crc, count: 4))
        var originalSize = UInt32(data.count & 0xFFFFFFFF)
        result.append(Data(bytes: &originalSize, count: 4))

        return result
    }

    static func gzipDecompress(data: Data) -> Data? {
        guard data.count > 10, data[0] == 0x1f, data[1] == 0x8b else {
            return inflate(data: data)
        }

        var headerLen = 10
        let flags = data[3]
        if flags & 0x04 != 0 {
            guard data.count > headerLen + 2 else { return nil }
            let extraLen = Int(data[headerLen]) | (Int(data[headerLen + 1]) << 8)
            headerLen += 2 + extraLen
        }
        if flags & 0x08 != 0 {
            while headerLen < data.count && data[headerLen] != 0 { headerLen += 1 }
            headerLen += 1
        }
        if flags & 0x10 != 0 {
            while headerLen < data.count && data[headerLen] != 0 { headerLen += 1 }
            headerLen += 1
        }
        if flags & 0x02 != 0 { headerLen += 2 }

        guard headerLen < data.count else { return nil }
        let compressed = data[headerLen..<max(headerLen, data.count - 8)]
        return inflate(data: Data(compressed))
    }

    private static func inflate(data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        let bufferSize = max(data.count * 10, 4096)
        var decompressed = Data(count: bufferSize)

        let written = decompressed.withUnsafeMutableBytes { destPtr -> Int in
            data.withUnsafeBytes { srcPtr -> Int in
                let dest = destPtr.bindMemory(to: UInt8.self)
                let src = srcPtr.bindMemory(to: UInt8.self)
                return compression_decode_buffer(
                    dest.baseAddress!, bufferSize,
                    src.baseAddress!, data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard written > 0 else { return nil }
        decompressed.count = written
        return decompressed
    }

    private static func crc32(data: Data) -> UInt32 {
        let table: [UInt32] = (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1 != 0) ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
