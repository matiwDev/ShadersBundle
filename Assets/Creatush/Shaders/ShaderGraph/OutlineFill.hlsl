#ifndef PI
#define PI 3.14159265359
#define HALF_PI 1.57079632679
#endif

void FoldedAbs_12SegmentTrailFill_float(
    float2 UV,          // [0..1], shape folded with abs(UV*2 - 1)
    float Width,        // half-width in folded coords
    float Height,       // half-height in folded coords
    float Radius,       // corner radius
    float Fill,         // [0..1] fraction of total perimeter
    out float Out       // final mask
)
{
    // Early exit
    float fillFrac = saturate(Fill);
    if (fillFrac <= 0.0) { Out = 0.0; return; }
    if (fillFrac >= 1.0) { Out = 1.0; return; }

    // Correct radius clamping (now using 0.5* dimensions)
    Radius = min(Radius, min(Width*0.5, Height*0.5));

    // PROPER edge length calculations
    float horizEdge = max(0.0, Width*0.5 - Radius); // Each straight segment is half-width
    float vertEdge = max(0.0, Height*0.5 - Radius);
    float arcLen = HALF_PI * Radius;

    // Total perimeter (4 straight segments + 4 arcs)
    float totalLen = 4.0 * (horizEdge + vertEdge + arcLen);

    // Debug: Output total perimeter components
    // return Out = totalLen / (Width+Height); // Uncomment to visualize

    // Precise threshold calculation
    float thresholds[13];
    thresholds[0] = 0.0;
    
    // First quadrant (top-right)
    thresholds[1] = thresholds[0] + horizEdge / totalLen;    // Right edge
    thresholds[2] = thresholds[1] + arcLen / totalLen;       // Top-right arc
    thresholds[3] = thresholds[2] + vertEdge / totalLen;     // Top edge
    
    // Second quadrant (bottom-right)
    thresholds[4] = thresholds[3] + vertEdge / totalLen;
    thresholds[5] = thresholds[4] + arcLen / totalLen;
    thresholds[6] = thresholds[5] + horizEdge / totalLen;
    
    // Third quadrant (bottom-left)
    thresholds[7] = thresholds[6] + horizEdge / totalLen;
    thresholds[8] = thresholds[7] + arcLen / totalLen;
    thresholds[9] = thresholds[8] + vertEdge / totalLen;
    
    // Fourth quadrant (top-left)
    thresholds[10] = thresholds[9] + vertEdge / totalLen;
    thresholds[11] = thresholds[10] + arcLen / totalLen;
    thresholds[12] = 1.0;

    // Get quadrant (-1 or +1 in each axis)
    float2 rawUV = UV * 2.0 - 1.0;
    int2 quadrant = sign(rawUV);
    
    // Common arc center calculations
    float2 centers[4];
    centers[0] = float2((0.5 + 0.5 * Width) - Radius, (0.5 + 0.5 * Height) - Radius);  // Top-right
    centers[1] = float2((0.5 + 0.5 * Width) - Radius, (0.5 - 0.5 * Height) + Radius);   // Bottom-right
    centers[2] = float2((0.5 - 0.5 * Width) + Radius, (0.5 - 0.5 * Height) + Radius);  // Bottom-left
    centers[3] = float2((0.5 - 0.5 * Width) + Radius, (0.5 + 0.5 * Height) - Radius);  // Top-left

    float mask = 0.0;
    
    // Macro for segment fill calculation
    #define SEGMENT_FILL(idx) saturate((fillFrac - thresholds[idx]) / max(1e-5, thresholds[idx+1] - thresholds[idx]))
    
    // Top-right quadrant
    if (quadrant.x >= 0 && quadrant.y >= 0)
    {
        float f1 = SEGMENT_FILL(0);  // Top edge
        float f2 = SEGMENT_FILL(1);  // Top-right arc
        float f3 = SEGMENT_FILL(2);  // Right edge top
        
        // Segment 1: Top edge (right side)
        if (f1 > 0.0)
        {
            float xEnd = lerp(0.5, 1.0 - Radius - (1.0 - Width) * 0.5, f1);
            mask = (UV.x >= 0.5 && UV.x <= xEnd && UV.y >= 0.5 && UV.y <= 0.5 + Height) ? 1.0 : mask;
        }
        
        // Segment 2: Top-right arc
        if (f2 > 0.0)
        {
            float2 rel = UV - centers[0];
            float angle = atan2(rel.y, rel.x);
            float cw = HALF_PI - angle;
            mask = (cw >= 0.0 && cw <= f2 * HALF_PI) ? 1.0 : mask;
        }
        
        // Segment 3: Right edge (top)
        if (f3 > 0.0)
        {
            float yEnd = lerp(1.0 - Radius - (1.0 - Height) * 0.5, 0.5, f3);
            mask = (UV.x >= 0.5 && UV.x <= 1.0 && UV.y <= 1.0 - Radius - (1.0 - Height) * 0.5 && UV.y >= yEnd) ? 1.0 : mask;
        }
    }
    
    // Bottom-right quadrant
    else if (quadrant.x >= 0 && quadrant.y < 0)
    {
        float f4 = SEGMENT_FILL(3);  // Right edge bottom
        float f5 = SEGMENT_FILL(4);  // Bottom-right arc
        float f6 = SEGMENT_FILL(5);  // Bottom edge right
        
        // Segment 4: Right edge (bottom)
        if (f4 > 0.0)
        {
            float yEnd = lerp(0.5, Radius + (1.0 - Height) * 0.5, f4);
            mask = (UV.x >= 0.5 && UV.x <= 1.0 && UV.y <= 0.5 && UV.y >= yEnd) ? 1.0 : mask;
        }
        
        // Segment 5: Bottom-right arc
        if (f5 > 0.0)
        {
            float2 rel = UV - centers[1];
            float angle = atan2(rel.y, rel.x);
            mask = (angle <= 0.0 && angle >= -f5 * HALF_PI) ? 1.0 : mask;
        }
        
        // Segment 6: Bottom edge (right)
        if (f6 > 0.0)
        {
            float xEnd = lerp(1.0 - Radius - (1.0 - Width) * 0.5, 0.5, f6);
            mask = (UV.x <= 1.0 - Radius - (1.0 - Width) * 0.5 && UV.x >= xEnd && 
                   UV.y >= 0.5 - Height && UV.y <= 0.5) ? 1.0 : mask;
        }
    }
    
    // Bottom-left quadrant
    else if (quadrant.x < 0 && quadrant.y < 0)
    {
        float f7 = SEGMENT_FILL(6);  // Bottom edge left
        float f8 = SEGMENT_FILL(7);  // Bottom-left arc
        float f9 = SEGMENT_FILL(8);  // Left edge bottom
        
        // Segment 7: Bottom edge (left)
        if (f7 > 0.0)
        {
            float xEnd = lerp(0.5, Radius + (1.0 - Width) * 0.5, f7);
            mask = (UV.x <= 0.5 && UV.x >= xEnd && 
                   UV.y >= 0.5 - Height && UV.y <= 0.5) ? 1.0 : mask;
        }
        
        // Segment 8: Bottom-left arc
        if (f8 > 0.0)
        {
            float2 rel = UV - centers[2];
            float angle = atan2(rel.y, rel.x);
            mask = (angle <= -HALF_PI && angle >= -HALF_PI - f8 * HALF_PI) ? 1.0 : mask;
        }
        
        // Segment 9: Left edge (bottom)
        if (f9 > 0.0)
        {
            float yEnd = lerp(Radius + (1.0 - Height) * 0.5, 0.5, f9);
            mask = (UV.x >= 0.0 && UV.x <= 0.5 && UV.y >= Radius + (1.0 - Height) * 0.5 && UV.y <= yEnd) ? 1.0 : mask;
        }
    }
    
    // Top-left quadrant
    else if (quadrant.x < 0 && quadrant.y >= 0)
    {
        float f10 = SEGMENT_FILL(9);  // Left edge top
        float f11 = SEGMENT_FILL(10); // Top-left arc
        float f12 = SEGMENT_FILL(11); // Top edge left
        
        // Segment 10: Left edge (top)
        if (f10 > 0.0)
        {
            float yEnd = lerp(0.5, 1.0 - Radius - (1.0 - Height) * 0.5, f10);
            mask = (UV.x >= 0.0 && UV.x <= 0.5 && UV.y >= 0.5 && UV.y <= yEnd) ? 1.0 : mask;
        }
        
        // Segment 11: Top-left arc
        if (f11 > 0.0)
        {
            float2 rel = UV - centers[3];
            float angle = atan2(rel.y, rel.x);
            angle = PI - angle;
            angle = angle + HALF_PI;
            mask = (angle >= HALF_PI && angle <= HALF_PI + f11 * HALF_PI) ? 1.0 : mask;
        }
        
        // Segment 12: Top edge (left)
        if (f12 > 0.0)
        {
            float xEnd = lerp(Radius + (1.0 - Width) * 0.5, 0.5, f12);
            mask = (UV.x >= Radius + (1.0 - Width) * 0.5 && UV.x <= xEnd && 
                   UV.y >= 0.5 && UV.y <= 0.5 + Height) ? 1.0 : mask;
        }
    }
    
    Out = mask;
}