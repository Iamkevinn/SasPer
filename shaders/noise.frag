#version 460 core
#include <flutter/runtime_effect.glsl>

out vec4 fragColor;

// Variables que Flutter nos da
uniform vec2 uSize;

// Función para generar un número pseudoaleatorio (ruido)
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void main() {
    vec2 st = FlutterFragCoord().xy / uSize.xy;
    float rnd = random(st);

    // Creamos un color de ruido gris con muy baja opacidad
    fragColor = vec4(vec3(rnd), 0.04);
}