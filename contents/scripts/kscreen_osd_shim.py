#!/usr/bin/env /usr/bin/python3
import sys
import os
import subprocess
from dasbus.loop import EventLoop
from dasbus.connection import SessionMessageBus

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TOGGLE_SCRIPT = os.path.join(SCRIPT_DIR, "toggle_window.sh")

class ScreenManagerOSD(object):
    __dbus_xml__ = """
    <node>
        <interface name="org.kde.kscreen.osdService">
            <method name="showActionSelector">
            </method>
            <method name="hideOsd">
            </method>
        </interface>
    </node>
    """
    def showActionSelector(self):
        try:
            subprocess.Popen([TOGGLE_SCRIPT])
        except Exception as e:
            print(f"Failed to launch toggle script: {e}", file=sys.stderr)

    def hideOsd(self):
        pass

def main():
    bus = SessionMessageBus()
    bus.publish_object("/org/kde/kscreen/osdService", ScreenManagerOSD())
    bus.register_service("org.kde.kscreen.osdService")
    loop = EventLoop()
    loop.run()

if __name__ == "__main__":
    main()
