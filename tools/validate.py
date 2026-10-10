"""Compile + link every program of the pack with the local OpenGL driver.

Creates a hidden window / legacy (compatibility) GL context through ctypes,
expands Iris-style #includes and reports driver errors mapped back to the
original file + line.

usage: python tools/validate.py
"""
import ctypes
import ctypes.wintypes as wt
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shaders")
ROOT = os.path.normpath(ROOT)

user32 = ctypes.WinDLL("user32")
gdi32 = ctypes.WinDLL("gdi32")
gl = ctypes.WinDLL("opengl32")


class PFD(ctypes.Structure):
    _fields_ = [
        ("nSize", wt.WORD), ("nVersion", wt.WORD), ("dwFlags", wt.DWORD),
        ("iPixelType", ctypes.c_ubyte), ("cColorBits", ctypes.c_ubyte),
        ("cRedBits", ctypes.c_ubyte), ("cRedShift", ctypes.c_ubyte),
        ("cGreenBits", ctypes.c_ubyte), ("cGreenShift", ctypes.c_ubyte),
        ("cBlueBits", ctypes.c_ubyte), ("cBlueShift", ctypes.c_ubyte),
        ("cAlphaBits", ctypes.c_ubyte), ("cAlphaShift", ctypes.c_ubyte),
        ("cAccumBits", ctypes.c_ubyte), ("cAccumRedBits", ctypes.c_ubyte),
        ("cAccumGreenBits", ctypes.c_ubyte), ("cAccumBlueBits", ctypes.c_ubyte),
        ("cAccumAlphaBits", ctypes.c_ubyte), ("cDepthBits", ctypes.c_ubyte),
        ("cStencilBits", ctypes.c_ubyte), ("cAuxBuffers", ctypes.c_ubyte),
        ("iLayerType", ctypes.c_ubyte), ("bReserved", ctypes.c_ubyte),
        ("dwLayerMask", wt.DWORD), ("dwVisibleMask", wt.DWORD), ("dwDamageMask", wt.DWORD),
    ]


def make_context():
    user32.CreateWindowExW.restype = wt.HWND
    user32.CreateWindowExW.argtypes = [wt.DWORD, wt.LPCWSTR, wt.LPCWSTR, wt.DWORD, ctypes.c_int, ctypes.c_int,
                                       ctypes.c_int, ctypes.c_int, wt.HWND, wt.HMENU, wt.HINSTANCE, wt.LPVOID]
    hwnd = user32.CreateWindowExW(0, "STATIC", "glcheck", 0x00CF0000, 0, 0, 64, 64, None, None, None, None)
    user32.GetDC.restype = wt.HDC
    user32.GetDC.argtypes = [wt.HWND]
    hdc = user32.GetDC(hwnd)
    pfd = PFD()
    pfd.nSize = ctypes.sizeof(PFD)
    pfd.nVersion = 1
    pfd.dwFlags = 0x4 | 0x20 | 0x1  # DRAW_TO_WINDOW | SUPPORT_OPENGL | DOUBLEBUFFER
    pfd.cColorBits = 32
    pfd.cDepthBits = 24
    gdi32.ChoosePixelFormat.argtypes = [wt.HDC, ctypes.POINTER(PFD)]
    gdi32.SetPixelFormat.argtypes = [wt.HDC, ctypes.c_int, ctypes.POINTER(PFD)]
    fmt = gdi32.ChoosePixelFormat(hdc, ctypes.byref(pfd))
    gdi32.SetPixelFormat(hdc, fmt, ctypes.byref(pfd))
    gl.wglCreateContext.restype = wt.HANDLE
    gl.wglCreateContext.argtypes = [wt.HDC]
    gl.wglMakeCurrent.argtypes = [wt.HDC, wt.HANDLE]
    ctx = gl.wglCreateContext(hdc)
    if not ctx or not gl.wglMakeCurrent(hdc, ctx):
        raise SystemExit("could not create GL context")
    gl.glGetString.restype = ctypes.c_char_p
    print("GL:", gl.glGetString(0x1F02).decode(), "|", gl.glGetString(0x1F01).decode())


def proc(name, restype, *argtypes):
    gl.wglGetProcAddress.restype = ctypes.c_void_p
    gl.wglGetProcAddress.argtypes = [ctypes.c_char_p]
    addr = gl.wglGetProcAddress(name.encode())
    return ctypes.WINFUNCTYPE(restype, *argtypes)(addr)


make_context()
GLuint, GLint, GLenum = ctypes.c_uint, ctypes.c_int, ctypes.c_uint
glCreateShader = proc("glCreateShader", GLuint, GLenum)
glShaderSource = proc("glShaderSource", None, GLuint, ctypes.c_int, ctypes.POINTER(ctypes.c_char_p), ctypes.c_void_p)
glCompileShader = proc("glCompileShader", None, GLuint)
glGetShaderiv = proc("glGetShaderiv", None, GLuint, GLenum, ctypes.POINTER(GLint))
glGetShaderInfoLog = proc("glGetShaderInfoLog", None, GLuint, ctypes.c_int, ctypes.c_void_p, ctypes.c_char_p)
glCreateProgram = proc("glCreateProgram", GLuint)
glAttachShader = proc("glAttachShader", None, GLuint, GLuint)
glLinkProgram = proc("glLinkProgram", None, GLuint)
glGetProgramiv = proc("glGetProgramiv", None, GLuint, GLenum, ctypes.POINTER(GLint))
glGetProgramInfoLog = proc("glGetProgramInfoLog", None, GLuint, ctypes.c_int, ctypes.c_void_p, ctypes.c_char_p)

INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"')


def expand(path, origin=None, depth=0):
    """Return list of (line, file, lineno)."""
    out = []
    with open(path, encoding="utf-8") as f:
        for i, line in enumerate(f.read().splitlines(), 1):
            m = INCLUDE_RE.match(line)
            if m:
                inc = m.group(1)
                full = os.path.join(ROOT, inc.lstrip("/")) if inc.startswith("/") else os.path.join(os.path.dirname(path), inc)
                out += expand(os.path.normpath(full), path, depth + 1)
            else:
                out.append((line, os.path.relpath(path, ROOT), i))
    return out


def compile_stage(lines, stage):
    src = "\n".join(l for l, _, _ in lines).encode()
    sh = glCreateShader(0x8B31 if stage == "vsh" else 0x8B30)
    arr = (ctypes.c_char_p * 1)(src)
    glShaderSource(sh, 1, arr, None)
    glCompileShader(sh)
    ok = GLint()
    glGetShaderiv(sh, 0x8B81, ctypes.byref(ok))
    buf = ctypes.create_string_buffer(65536)
    glGetShaderInfoLog(sh, 65536, None, buf)
    log = buf.value.decode(errors="replace")
    return sh, ok.value, log


def map_log(log, lines):
    res = []
    for ln in log.splitlines():
        m = re.match(r"0\((\d+)\)\s*:\s*(.*)", ln)
        if m:
            n = int(m.group(1))
            if 1 <= n <= len(lines):
                _, fn, no = lines[n - 1]
                res.append(f"    {fn}:{no}: {m.group(2)}")
                continue
        if ln.strip():
            res.append("    " + ln)
    return "\n".join(res)


errors = 0
warnings = 0
for folder in ("world0", "world-1", "world1"):
    d = os.path.join(ROOT, folder)
    progs = sorted({os.path.splitext(f)[0] for f in os.listdir(d)})
    for p in progs:
        shaders = []
        failed = False
        for stage in ("vsh", "fsh"):
            lines = expand(os.path.join(d, f"{p}.{stage}"))
            sh, ok, log = compile_stage(lines, stage)
            shaders.append(sh)
            if not ok:
                failed = True
                errors += 1
                print(f"[FAIL] {folder}/{p}.{stage}\n{map_log(log, lines)}")
            elif "warning" in log.lower():
                warnings += 1
                if "-v" in sys.argv:
                    print(f"[warn] {folder}/{p}.{stage}\n{map_log(log, lines)}")
        if failed:
            continue
        prog = glCreateProgram()
        for sh in shaders:
            glAttachShader(prog, sh)
        glLinkProgram(prog)
        ok = GLint()
        glGetProgramiv(prog, 0x8B82, ctypes.byref(ok))
        if not ok.value:
            buf = ctypes.create_string_buffer(65536)
            glGetProgramInfoLog(prog, 65536, None, buf)
            errors += 1
            print(f"[LINK FAIL] {folder}/{p}\n    {buf.value.decode(errors='replace')}")
        else:
            print(f"[ ok ] {folder}/{p}")

print(f"\n{errors} error(s), {warnings} stage(s) with warnings")
sys.exit(1 if errors else 0)
