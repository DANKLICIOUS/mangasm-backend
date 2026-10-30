const canvas = document.querySelector('#storm');
const button = document.querySelector('#motion');
const status = document.querySelector('#render-status');
const artwork = document.querySelector('#artwork');
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

function artworkFallback() {
  artwork.hidden = true;
  document.querySelector('#artwork-caption').textContent =
    'STORM SIGIL / ARTWORK UNAVAILABLE';
}
artwork.addEventListener('error', artworkFallback);
if (artwork.complete && !artwork.naturalWidth) artworkFallback();

const vertexSource = `
  attribute vec2 position;
  void main() {
    gl_Position = vec4(position, 0.0, 1.0);
  }
`;
const fragmentSource = `
  precision mediump float;
  uniform vec2 resolution;
  uniform vec2 pointer;
  uniform float time;

  float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
  }
  float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
      mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
  }
  float mist(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
      value += amplitude * noise(p);
      p = p * 2.03 + vec2(4.1, 7.3);
      amplitude *= 0.5;
    }
    return value;
  }
  void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    vec2 p = (gl_FragCoord.xy - 0.5 * resolution) / resolution.y;
    p += pointer * 0.06;
    float t = time * 0.12;
    float clouds = mist(p * 3.0 + vec2(t * 0.3, -t * 0.2));
    float veil = mist(p * 5.0 + clouds + vec2(-t * 0.2, t * 0.3));
    vec3 color = vec3(0.023, 0.018, 0.043);
    color += vec3(0.15, 0.08, 0.24) * clouds * veil;

    // Continuous filaments rather than full-screen lightning flashes.
    for (int i = 0; i < 3; i++) {
      float lane = float(i);
      float path = (lane - 1.0) * 0.45;
      path += 0.16 * sin(p.y * 5.0 + t + lane * 2.0);
      path += 0.065 * (noise(vec2(p.y * 24.0 + t, lane * 9.0)) - 0.5);
      float distanceToBolt = abs(p.x - path);
      float envelope = 0.45 + 0.25 * sin(t * 1.5 + lane);
      float glow = 0.002 / (distanceToBolt + 0.008);
      color += vec3(0.35, 0.16, 0.65) * glow * envelope;
    }

    vec2 dust = p * 36.0 + vec2(t * 0.5, t);
    vec2 cell = floor(dust);
    vec2 center = vec2(hash(cell), hash(cell + 17.0));
    float star = 1.0 - smoothstep(0.015, 0.09, length(fract(dust) - center));
    star *= step(0.94, hash(cell + 31.0));
    color += vec3(0.65, 0.52, 0.9) * star * 0.5;
    color *= 1.0 - 0.4 * length(uv - 0.5);
    gl_FragColor = vec4(color, 1.0);
  }
`;

let gl;
let program;
let buffer;
let uniforms;
let frame = null;
let elapsed = 0;
let previous = null;
let enabled = !reducedMotion.matches;
let available = false;
let target = [0, 0];
let pointer = [0, 0];

function stop() {
  if (frame !== null) cancelAnimationFrame(frame);
  frame = null;
  previous = null;
}

function release() {
  if (buffer) gl.deleteBuffer(buffer);
  if (program) gl.deleteProgram(program);
  buffer = null;
  program = null;
}

function fallback() {
  stop();
  available = false;
  button.disabled = true;
  button.textContent = 'Motion unavailable';
  button.setAttribute('aria-pressed', 'false');
  status.textContent = 'Static atmosphere / WebGL unavailable';
  canvas.style.visibility = 'hidden';
}

function compile(type, source) {
  const shader = gl.createShader(type);
  if (!shader) throw new Error('Shader allocation failed');
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    gl.deleteShader(shader);
    throw new Error('Shader compilation failed');
  }
  return shader;
}

function initialize() {
  let vertex;
  let fragment;
  try {
    gl = canvas.getContext('webgl', {
      alpha: false, antialias: false, depth: false, powerPreference: 'low-power',
    });
    if (!gl) return fallback();
    vertex = compile(gl.VERTEX_SHADER, vertexSource);
    fragment = compile(gl.FRAGMENT_SHADER, fragmentSource);
    program = gl.createProgram();
    if (!program) throw new Error('Program allocation failed');
    gl.attachShader(program, vertex);
    gl.attachShader(program, fragment);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      throw new Error('Shader linking failed');
    }
    gl.useProgram(program);
    buffer = gl.createBuffer();
    if (!buffer) throw new Error('Buffer allocation failed');
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);
    const position = gl.getAttribLocation(program, 'position');
    gl.enableVertexAttribArray(position);
    gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
    uniforms = Object.fromEntries(['resolution', 'pointer', 'time']
      .map(name => [name, gl.getUniformLocation(program, name)]));
    available = true;
    canvas.style.visibility = '';
    button.disabled = false;
    resize();
    sync();
  } catch {
    if (gl) release();
    fallback();
  } finally {
    if (vertex) gl.deleteShader(vertex);
    if (fragment) gl.deleteShader(fragment);
  }
}

function draw() {
  if (!available || gl.isContextLost()) return;
  gl.viewport(0, 0, canvas.width, canvas.height);
  gl.uniform2f(uniforms.resolution, canvas.width, canvas.height);
  gl.uniform2f(uniforms.pointer, ...pointer);
  gl.uniform1f(uniforms.time, elapsed);
  gl.drawArrays(gl.TRIANGLES, 0, 6);
}

function resize() {
  if (!available) return;
  // Bound GPU work on Retina/4K displays as well as mobile devices.
  const scale = Math.min(window.devicePixelRatio || 1, 1.5,
    1600 / Math.max(window.innerWidth, window.innerHeight));
  canvas.width = Math.max(1, Math.round(window.innerWidth * scale));
  canvas.height = Math.max(1, Math.round(window.innerHeight * scale));
  draw();
}

function animate(now) {
  frame = null;
  if (!available || !enabled || document.hidden) return;
  if (previous !== null) elapsed += Math.min((now - previous) / 1000, 0.05);
  previous = now;
  pointer = pointer.map((value, index) => value + (target[index] - value) * 0.035);
  draw();
  frame = requestAnimationFrame(animate);
}

function sync() {
  stop();
  if (!available) return;
  button.textContent = enabled ? 'Pause motion' : 'Enable motion';
  button.setAttribute('aria-pressed', String(enabled));
  status.textContent = enabled ? 'WebGL / storm field active' : 'WebGL / still frame';
  draw();
  if (enabled && !document.hidden) frame = requestAnimationFrame(animate);
}

button.addEventListener('click', () => { enabled = !enabled; sync(); });
reducedMotion.addEventListener('change', () => {
  enabled = !reducedMotion.matches;
  target = [0, 0];
  pointer = [0, 0];
  sync();
});
window.addEventListener('pointermove', event => {
  if (!enabled || event.pointerType === 'touch') return;
  target = [event.clientX / window.innerWidth - 0.5, 0.5 - event.clientY / window.innerHeight];
}, { passive: true });
document.addEventListener('pointerleave', () => { target = [0, 0]; });
window.addEventListener('resize', resize, { passive: true });
document.addEventListener('visibilitychange', sync);
window.addEventListener('pagehide', stop);
window.addEventListener('pageshow', sync);
canvas.addEventListener('webglcontextlost', event => {
  event.preventDefault();
  fallback();
});
canvas.addEventListener('webglcontextrestored', () => {
  program = null;
  buffer = null;
  initialize();
});
initialize();
