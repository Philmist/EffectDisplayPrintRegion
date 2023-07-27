
#include "ReShade.fxh"

// Constant: Size presets (Long-side, Short-side)[mm]

static const float2 preset3R = float2(127f, 89f);  // L(jp), 3R(us)
static const float2 preset5R = float2(178f, 127f);  // 2L(jp), 5R(us)
static const float2 presetKG = float2(152f, 102f);  // KG(us, jp), 4R(us)
static const float2 presetA4 = float2(297f, 210f);  // A4(iso)
static const float2 presetA3 = float2(420f, 297f);  // A3(iso)
static const float2 presetHagaki = float2(148f, 100f);  // Yu-bin Hagaki(jp)

// Constant: Color

static const float4 colorWhite = float4(1.0f, 1.0f, 1.0f, 1.0f);

// UI: Options

uniform float fMaskAlpha <
  ui_type = "drag";
  ui_label = "Alpha";
  ui_min = 0.0;
  ui_max = 1.0;
  ui_step = 0.1;
> = 0.3;

uniform int iPresetSelect <
  ui_type = "combo";
  ui_label = "Paper";
  ui_items = " L-format(3R)\0 2L-format(5R)\0 A4\0 Hagaki\0 KG(4R)\0 A3\0";
> = 0;

static const float2 sizePresets[] = {preset3R, preset5R, presetA4, presetHagaki, presetKG, presetA3};

uniform int iOrientation <
  ui_type = "radio";
  ui_items = " Landscape\0 Portrait\0";
> = 0;

// Pixel Shader(s)

void PS_DrawRegion(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD, out float4 color : SV_Target) {
  // Get back buffer (image before pixel shader are applied)
  const float4 origColor = tex2D(ReShade::BackBuffer, texcoord);
  const float2 screenSize = ReShade::ScreenSize;

  const bool isWidthLarger = screenSize.x >= screenSize.y;
  const float2 maskSelectedSize = sizePresets[iPresetSelect];
  const float2 maskOrigSize = iOrientation == 0 ? maskSelectedSize : float2(maskSelectedSize.y, maskSelectedSize.x);

  // --
  // when: fit Y-axis(height)
  // texcoord:[0.0f, 1.0f], screen[0, screenHeight], mask[0, maskHeight]
  // --
  // texcoord:[0.0f, startT, endT, 1.0f], screen[0, startS, endS, screenWidth]
  // maskAspectRatio := maskWidth / maskHeight
  // -> maskAspectRatio == abs(startS - endS) / screenHeight
  // -> maskAspectRatio * screenHeight == abs(startS - endS)
  // <- [0.0f, startT, endT, 1.0f] == [0, startS/screenWidth, endS/screenWidth, 1]
  // -> maskAspectRatio * screenHeight / screenWidth = abs(startS - endS) / screenWidth
  // deltaS := maskAspectRatio * screenHeight
  // centerS := centerT * screenWidth
  // -> abs(startS - endS) == abs((centerS - deltaS/2) - (centerS + deltaS/2))
  // <- maskAspectRatio * screenHeight / screenWidth = deltaS / screenWidth
  // deltaT := deltaS / screenWidth == maskAspectRatio * screenHeight / screenWidth
  // screenAspectRatio := screenWidth / screenHeight
  // -> deltaT == maskAspectRatio / screenAspectRatio
  // ------
  // when: fit X-axis(width)
  // swap: screenHeight <-> screenWidth, maskHeight <-> maskWidth
  const float screenAspectRatio = isWidthLarger ? screenSize.x / screenSize.y : screenSize.y / screenSize.x;
  const float maskAspectRatio = isWidthLarger ? maskOrigSize.x / maskOrigSize.y : maskOrigSize.y / maskOrigSize.x;
  const float deltaTexcoord = maskAspectRatio / screenAspectRatio;
  const float2 startTexcoord = isWidthLarger ? float2((0.5f - deltaTexcoord/2), 0.0f) : float2(0.0f, (0.5f - deltaTexcoord / 2));
  const float2 endTexcoord = isWidthLarger ? float2((0.5f + deltaTexcoord/2), 1.0f) : float2(1.0f, (0.5f + deltaTexcoord/2));

  color = origColor;
  const bool2 isContain = (startTexcoord <= texcoord) && (texcoord <= endTexcoord);
  if (all(isContain)) {
    color = lerp(origColor, colorWhite, fMaskAlpha);
  }
}

// technique

technique DisplayPrintRegion <
  ui_tooltip = "Displays on-screen guides for printing on paper.\n";
> {
  pass Mask {
    VertexShader = PostProcessVS;
    PixelShader = PS_DrawRegion;
  }
}
