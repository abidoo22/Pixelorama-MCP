import ctypes
import time

x11 = ctypes.CDLL("libX11.so.6")
xtest = ctypes.CDLL("libXtst.so.6")

class Display(ctypes.Structure):
    pass

x11.XOpenDisplay.restype = ctypes.POINTER(Display)
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]

display = x11.XOpenDisplay(None)
if not display:
    print("Cannot open display")
    exit(1)

root = x11.XDefaultRootWindow(display)

# Move mouse and click at (x, y)
def click(x, y):
    # Move pointer
    x11.XWarpPointer(display, None, root, 0, 0, 0, 0, x, y)
    x11.XFlush(display)
    time.sleep(0.1)
    
    # Send button press
    xtest.XTestFakeButtonEvent(display, 1, True, 0)
    x11.XFlush(display)
    time.sleep(0.05)
    
    # Send button release
    xtest.XTestFakeButtonEvent(display, 1, False, 0)
    x11.XFlush(display)
    time.sleep(0.1)

# Click on "Edit" menu (X=42, Y=47)
click(42, 47)
print("Clicked on Edit menu.")
