import Foundation

/// Every key that can appear on an element in the `.excalidraw` flat object.
/// Base and type-specific fields share one keyed container so the model decodes
/// and encodes the exact flat shape Excalidraw uses.
enum ElementCodingKeys: String, CodingKey {
    // Base
    case id, type, x, y, width, height, angle
    case strokeColor, backgroundColor, fillStyle, strokeWidth, strokeStyle
    case roundness, roughness, opacity, seed, version, versionNonce, index
    case isDeleted, groupIds, frameId, boundElements, updated, link, locked, customData

    // Text
    case fontSize, fontFamily, text, textAlign, verticalAlign
    case containerId, originalText, autoResize, lineHeight

    // Linear / arrow (points shared with freedraw)
    case points, startBinding, endBinding, startArrowhead, endArrowhead
    case polygon, elbowed, fixedSegments, startIsSpecial, endIsSpecial

    /// Freedraw
    case pressures, simulatePressure

    /// Image
    case fileId, status, scale, crop

    /// Frame / magicframe
    case name
}
