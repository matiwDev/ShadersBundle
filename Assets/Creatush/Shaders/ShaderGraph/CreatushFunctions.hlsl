void roundedBox_float (float2 UV, float Width, float Height, float Radius, out float Out)
{
	Radius = max(min(min(abs(Radius * 2), abs(Width)), abs(Height)), 1e-5);
	float2 uv = abs(UV * 2 - 1) - float2(Width, Height) + Radius;
	Out = length(max(0, uv)) / Radius;
}	

// b.x = width
// b.y = height
// r.x = roundness top-right  
// r.y = roundness boottom-right
// r.z = roundness top-left
// r.w = roundness bottom-left
void sdRoundBox_float(float2 p, float2 b, float4 r, out float4 Out)
{
	r.xy = lerp(r.xy, r.zw, step(p.x, 0.0));
	r.x = lerp(r.x, r.y, step(p.y, 0.0));
	//r.xy = (p.x >0.0) ? r.xy : r.zw;
	//r.x = (p.y > 0.0) ? r.x : r.y;
	float2 q = abs(p) - b + r.x;
	Out = min(max(q.x, q.y), 0.0) + length(max(q, float2(0.0, 0.0))) - r.x;
}

void blend_float(float4 SourceColor, float SourceAlpha, float4 DestinationColor, out float4 Out)
{
	Out = (SourceColor * SourceAlpha) + (DestinationColor * (1 - SourceAlpha));
}