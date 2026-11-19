#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 uSize;
uniform float uTime;
uniform vec2 uPointer;
uniform vec3 uA;
uniform vec3 uB;
uniform vec3 uC;
uniform vec3 uBackground;
uniform float uDensity;
out vec4 fragColor;
void main() {
  vec2 p = FlutterFragCoord().xy / uSize;
  vec2 q = (p - .5) * vec2(uSize.x/uSize.y, 1.0);
  q += (uPointer - .5) * .22;
  float a = sin(q.x*4.2 + sin(q.y*3.1 + uTime)*1.6 + uTime*.43);
  float b = cos(q.y*5.1 + sin(q.x*3.8 - uTime*.7)*1.5 - uTime*.36);
  float c = sin((q.x+q.y)*3.7 + a*1.8 - b*.9 + uTime*.28);
  float f = .5 + .5 * sin(a*2.3 + b*1.6 + c);
  float bands = pow(f, 2.0 + uDensity*2.0);
  vec3 color = mix(uA, uB, .5+.5*c);
  color = mix(color, uC, .25*(.5+.5*b));
  float envelope = (1.0 - smoothstep(.12, .95, length(q)));
  fragColor = vec4(mix(uBackground, color, bands*envelope*.83), 1.0);
}
