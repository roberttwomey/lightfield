#version 150
// these are for the programmable pipeline system and are passed in
// by default from OpenFrameworks
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 textureMatrix;
uniform mat4 modelViewProjectionMatrix;

in vec4 position;
in vec4 color;
in vec4 normal;
in vec2 texCoord;
// this is the end of the default functionality

// this is something we're creating for this shader
out vec2 texCoordV;

void main()
{
    // here we move the texture coordinates
    texCoordV = vec2(texCoord.x, texCoord.y);

    // send the vertices to the fragment shader
    gl_Position = modelViewProjectionMatrix * position;
}
