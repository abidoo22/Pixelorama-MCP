import ctypes
import time

x11 = ctypes.CDLL("libX11.so.6")

class Display(ctypes.Structure):
    pass

x11.XOpenDisplay.restype = ctypes.POINTER(Display)
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]

display = x11.XOpenDisplay(None)
if not display:
    print("Cannot open display")
    exit(1)

# Get active window
window = ctypes.c_ulong()
revert_to = ctypes.c_int()
x11.XGetInputFocus(display, ctypes.byref(window), ctypes.byref(revert_to))

print("Focused Window ID:", window.value)

class XKeyEvent(ctypes.Structure):
    _fields_ = [
        ("type", ctypes.c_int),
        ("serial", ctypes.c_ulong),
        ("send_event", ctypes.c_int),
        ("display", ctypes.c_void_p),
        ("window", ctypes.c_ulong),
        ("root", ctypes.c_ulong),
        ("subwindow", ctypes.c_ulong),
        ("time", ctypes.c_ulong),
        ("x", ctypes.c_int),
        ("y", ctypes.c_int),
        ("x_root", ctypes.c_int),
        ("y_root", ctypes.c_int),
        ("state", ctypes.c_uint),
        ("keycode", ctypes.c_uint),
        ("same_screen", ctypes.c_int)
    ]

# Comma keycode is usually 59, Ctrl modifier is 4 (ControlMask)
comma_keycode = x11.XKeysymToKeycode(display, 0x002c) # ',' is 0x002c
ctrl_keycode = x11.XKeysymToKeycode(display, 0xffe3) # XK_Control_L = 0xffe3
print("Comma keycode:", comma_keycode, "Ctrl keycode:", ctrl_keycode)

def send_key_event(window, keycode, is_press, state=0):
    event = XKeyEvent()
    event.type = 2 if is_press else 3
    event.display = ctypes.cast(display, ctypes.c_void_p)
    event.window = window
    event.root = x11.XDefaultRootWindow(display)
    event.time = int(time.time() * 1000)
    event.keycode = keycode
    event.state = state
    
    ptr = ctypes.pointer(event)
    x11.XSendEvent(display, window, True, 1, ctypes.cast(ptr, ctypes.c_void_p))
    x11.XFlush(display)

# Send Ctrl Press, Comma Press, Comma Release, Ctrl Release
send_key_event(window, ctrl_keycode, True)
time.sleep(0.05)
send_key_event(window, comma_keycode, True, 4) # 4 = ControlMask
time.sleep(0.05)
send_key_event(window, comma_keycode, False, 4)
time.sleep(0.05)
send_key_event(window, ctrl_keycode, False)

print("Sent Ctrl+, successfully.")
