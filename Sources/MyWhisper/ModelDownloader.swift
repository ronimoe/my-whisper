import Foundation

/// Downloads a whisper.cpp ggml model from Hugging Face straight into
/// Settings.modelsDir, so first-run users don't have to run a shell script.
/// This is the ONE place in the app that talks to a non-localhost host —
/// see PRIVACY.md and NetworkAuditTests for the documented exception, and
/// only when the user explicitly starts a download.
final class ModelDownloader: NSObject {
    static let shared = ModelDownloader()

    private var session: URLSession!
    private var task: URLSessionDownloadTask?
    private var modelName: String?
    private var progressHandler: ((Double, Int64, Int64) -> Void)?
    private var completionHandler: ((Result<URL, Error>) -> Void)?
    private let lock = NSLock()

    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    private(set) var isDownloading: Bool = false

    enum DownloadError: LocalizedError {
        case alreadyDownloading
        case httpStatus(Int)
        case moveFailed(String)

        var errorDescription: String? {
            switch self {
            case .alreadyDownloading:
                return "A model download is already in progress."
            case .httpStatus(let code):
                return "Download failed (server returned status \(code))."
            case .moveFailed(let message):
                return "Couldn't save the downloaded model: \(message)"
            }
        }
    }

    /// https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-<name>.bin
    static func modelURL(for name: String) -> URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(name).bin")!
    }

    /// Settings.modelsDir/ggml-<name>.bin
    static func destination(for name: String) -> URL {
        Settings.modelsDir.appendingPathComponent("ggml-\(name).bin")
    }

    /// Starts downloading `name` into Settings.modelsDir. Rejects a second
    /// concurrent download. Progress and completion are both delivered on
    /// the main queue.
    func download(model name: String,
                   progress: @escaping (Double, Int64, Int64) -> Void,
                   completion: @escaping (Result<URL, Error>) -> Void) {
        lock.lock()
        if isDownloading {
            lock.unlock()
            DispatchQueue.main.async { completion(.failure(DownloadError.alreadyDownloading)) }
            return
        }
        isDownloading = true
        modelName = name
        progressHandler = progress
        completionHandler = completion
        lock.unlock()

        let request = URLRequest(url: Self.modelURL(for: name))
        let downloadTask = session.downloadTask(with: request)
        task = downloadTask
        downloadTask.resume()
    }

    /// Cancels the active download, removes the partial file, and reports
    /// cancellation to the pending completion handler.
    func cancel() {
        lock.lock()
        guard isDownloading, let name = modelName else {
            lock.unlock()
            return
        }
        let completion = completionHandler
        task?.cancel()
        task = nil
        isDownloading = false
        modelName = nil
        progressHandler = nil
        completionHandler = nil
        lock.unlock()

        let partial = Self.destination(for: name).appendingPathExtension("part")
        try? FileManager.default.removeItem(at: partial)

        DispatchQueue.main.async { completion?(.failure(CancellationError())) }
    }

    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        let completion = completionHandler
        isDownloading = false
        modelName = nil
        progressHandler = nil
        completionHandler = nil
        task = nil
        lock.unlock()

        DispatchQueue.main.async { completion?(result) }
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                     didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                     totalBytesExpectedToWrite: Int64) {
        lock.lock()
        let handler = progressHandler
        lock.unlock()
        guard let handler else { return }
        let fraction = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        DispatchQueue.main.async {
            handler(fraction, totalBytesWritten, totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                     didFinishDownloadingTo location: URL) {
        lock.lock()
        let name = modelName
        lock.unlock()
        guard let name else { return }

        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            finish(.failure(DownloadError.httpStatus(httpResponse.statusCode)))
            return
        }

        let destination = Self.destination(for: name)
        let partial = destination.appendingPathExtension("part")
        do {
            try? FileManager.default.removeItem(at: partial)
            try FileManager.default.moveItem(at: location, to: partial)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: partial, to: destination)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: destination.path)
            finish(.success(destination))
        } catch {
            finish(.failure(DownloadError.moveFailed(error.localizedDescription)))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                     didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            // cancel() already reported this via finish/completion.
            return
        }
        finish(.failure(error))
    }
}
