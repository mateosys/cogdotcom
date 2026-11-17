// Converts an animated GIF to a looping-friendly H.264 .mp4 for <DitherImage>,
// using only what ships with macOS (ImageIO + AVFoundation). No ffmpeg needed.
//
//   swift scripts/gif-to-mp4.swift public/photos/clip.gif            -> public/photos/clip.mp4
//   swift scripts/gif-to-mp4.swift in.gif out.mp4 --scale 8          -> force 8x upscale
//   swift scripts/gif-to-mp4.swift in.gif out.mp4 --bg "#0a0907"     -> colour behind transparent pixels
//
// Small pixel-art GIFs are upscaled with nearest-neighbour (crisp pixels) so the shortest
// side is at least 360px (long side capped at 1920px); video encoders blur or reject tiny frames.

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

// ── arguments ───────────────────────────────────────────────
// Older `swift file.swift` (5.3 and earlier) passes its own compiler flags first, then "--", then ours
var args = CommandLine.arguments.firstIndex(of: "--").map { Array(CommandLine.arguments[($0 + 1)...]) }
    ?? Array(CommandLine.arguments.dropFirst())
var forcedScale: Int? = nil
var bgHex = "#000000"
if let i = args.firstIndex(of: "--scale"), i + 1 < args.count {
    guard let s = Int(args[i + 1]), s >= 1 else { fail("--scale needs a whole number, e.g. --scale 4") }
    forcedScale = s
    args.removeSubrange(i...(i + 1))
}
if let i = args.firstIndex(of: "--bg"), i + 1 < args.count {
    bgHex = args[i + 1]
    args.removeSubrange(i...(i + 1))
}
guard args.count == 1 || args.count == 2 else {
    fail("usage: swift scripts/gif-to-mp4.swift input.gif [output.mp4] [--scale N] [--bg #rrggbb]")
}
let inURL = URL(fileURLWithPath: args[0])
let outURL = args.count == 2
    ? URL(fileURLWithPath: args[1])
    : inURL.deletingPathExtension().appendingPathExtension("mp4")

func parseHex(_ h: String) -> (CGFloat, CGFloat, CGFloat) {
    var s = h.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let n = UInt32(s, radix: 16) else { fail("--bg must look like #rrggbb") }
    return (CGFloat((n >> 16) & 255) / 255, CGFloat((n >> 8) & 255) / 255, CGFloat(n & 255) / 255)
}
let (bgR, bgG, bgB) = parseHex(bgHex)

// ── read the GIF ────────────────────────────────────────────
guard let src = CGImageSourceCreateWithURL(inURL as CFURL, nil) else { fail("can't open \(inURL.path)") }
let count = CGImageSourceGetCount(src)
guard count > 0, let first = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fail("no frames in \(inURL.path)") }

// Frame delay in seconds. Browsers treat delays under 20ms as 100ms, so we do too.
func delay(at i: Int) -> Double {
    let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
    let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
    let d = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
        ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
    return d < 0.02 ? 0.1 : d
}

let srcW = first.width, srcH = first.height
// aim for a short side of 360px, but keep the long side within 1920px (wide banners/dividers)
let autoScale = min(Int((360.0 / Double(min(srcW, srcH))).rounded(.up)), 1920 / max(srcW, srcH))
let scale = forcedScale ?? max(1, autoScale)
// H.264 needs even dimensions
let outW = (srcW * scale + 1) / 2 * 2
let outH = (srcH * scale + 1) / 2 * 2

// ── set up the video writer ─────────────────────────────────
try? FileManager.default.removeItem(at: outURL)
let writer: AVAssetWriter
do { writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4) } catch { fail("can't write \(outURL.path): \(error)") }
writer.shouldOptimizeForNetworkUse = true // "faststart": playable before fully downloaded

let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: outW,
    AVVideoHeightKey: outH,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: max(400_000, outW * outH * 4),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    ],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: outW,
    kCVPixelBufferHeightKey as String: outH,
])
guard writer.canAdd(input) else { fail("video writer rejected the settings") }
writer.add(input)
guard writer.startWriting() else { fail("can't start writing: \(String(describing: writer.error))") }
writer.startSession(atSourceTime: .zero)

// ── draw each frame onto a solid background, upscaled with crisp pixels ──
let timescale: CMTimeScale = 1000
var t = 0.0
for i in 0..<count {
    guard let frame = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    guard let pool = adaptor.pixelBufferPool else { fail("no pixel buffer pool: \(String(describing: writer.error))") }
    var pbOut: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut)
    guard let pb = pbOut else { fail("couldn't allocate a frame buffer") }

    CVPixelBufferLockBaseAddress(pb, [])
    let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(pb), width: outW, height: outH, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.setFillColor(red: bgR, green: bgG, blue: bgB, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))
    ctx.interpolationQuality = .none
    ctx.draw(frame, in: CGRect(x: 0, y: outH - srcH * scale, width: srcW * scale, height: srcH * scale))
    CVPixelBufferUnlockBaseAddress(pb, [])

    let pts = CMTime(seconds: t, preferredTimescale: timescale)
    if !adaptor.append(pb, withPresentationTime: pts) { fail("failed on frame \(i): \(String(describing: writer.error))") }
    t += delay(at: i)
}

// ── finish ──────────────────────────────────────────────────
input.markAsFinished()
writer.endSession(atSourceTime: CMTime(seconds: t, preferredTimescale: timescale)) // last frame keeps its full delay
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
guard writer.status == .completed else { fail("writing failed: \(String(describing: writer.error))") }

// AVFoundation can leave a "<name>.mp4.sb-xxxx" scratch file next to the output; remove it
let dir = outURL.deletingLastPathComponent()
for leftover in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
    where leftover.hasPrefix(outURL.lastPathComponent + ".sb-") {
    try? FileManager.default.removeItem(at: dir.appendingPathComponent(leftover))
}

let bytes = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
print(String(format: "%@ → %@  (%d frames, %.2fs loop, %dx%d at %dx scale, %d KB)",
             inURL.lastPathComponent, outURL.lastPathComponent, count, t, outW, outH, scale, bytes / 1024))
