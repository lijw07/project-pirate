"""Offline macOS General MIDI renderer using the system AudioToolbox framework.

Only renders a composed score. Does not copy or distribute the system sound bank.
No compiler, developer tools, or downloaded packages beyond NumPy are needed.
"""
import ctypes as C
import json
import sys
from pathlib import Path
import numpy as np


def fourcc(value):
    return int.from_bytes(value.encode(), "big")


class Component(C.Structure):
    _fields_ = [(name, C.c_uint32) for name in ["type", "subtype", "manufacturer", "flags", "mask"]]


class Format(C.Structure):
    _fields_ = [("rate", C.c_double)] + [(name, C.c_uint32) for name in ["format", "flags", "bytes_packet", "frames_packet", "bytes_frame", "channels", "bits", "reserved"]]


class Timestamp(C.Structure):
    _fields_ = [("sample", C.c_double), ("host", C.c_uint64), ("rate", C.c_double),
                ("word", C.c_uint64), ("smpte", C.c_byte * 24), ("flags", C.c_uint32), ("reserved", C.c_uint32)]


class Buffer(C.Structure):
    _fields_ = [("channels", C.c_uint32), ("size", C.c_uint32), ("data", C.c_void_p)]


class Buffers(C.Structure):
    _fields_ = [("count", C.c_uint32), ("buffers", Buffer * 2)]


def render(score):
    au = C.CDLL("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox")
    signatures = {
        "AudioComponentFindNext": ([C.c_void_p, C.POINTER(Component)], C.c_void_p),
        "AudioComponentInstanceNew": ([C.c_void_p, C.POINTER(C.c_void_p)], C.c_int32),
        "AudioUnitSetProperty": ([C.c_void_p, C.c_uint32, C.c_uint32, C.c_uint32, C.c_void_p, C.c_uint32], C.c_int32),
        "AudioUnitInitialize": ([C.c_void_p], C.c_int32),
        "AudioUnitUninitialize": ([C.c_void_p], C.c_int32),
        "AudioComponentInstanceDispose": ([C.c_void_p], C.c_int32),
        "MusicDeviceMIDIEvent": ([C.c_void_p, C.c_uint32, C.c_uint32, C.c_uint32, C.c_uint32], C.c_int32),
        "AudioUnitRender": ([C.c_void_p, C.POINTER(C.c_uint32), C.POINTER(Timestamp), C.c_uint32, C.c_uint32, C.POINTER(Buffers)], C.c_int32),
    }
    for name, (args, result) in signatures.items():
        getattr(au, name).argtypes = args
        getattr(au, name).restype = result

    def check(status):
        if status: raise RuntimeError(f"AudioToolbox status {status}")

    desc = Component(fourcc("aumu"), fourcc("dls "), fourcc("appl"), 0, 0)
    component = au.AudioComponentFindNext(None, C.byref(desc))
    if not component: raise RuntimeError("macOS DLS synthesizer unavailable")
    unit = C.c_void_p()
    check(au.AudioComponentInstanceNew(component, C.byref(unit)))
    try:
        fmt = Format(44100, fourcc("lpcm"), 1 | 8 | 32, 4, 1, 4, 2, 32, 0)
        check(au.AudioUnitSetProperty(unit, 8, 2, 0, C.byref(fmt), C.sizeof(fmt)))
        check(au.AudioUnitInitialize(unit))

        def midi(status, a, b=0): check(au.MusicDeviceMIDIEvent(unit, status, a, b, 0))

        for part in score["parts"]:
            channel = part["channel"]
            midi(0xC0 | channel, part["program"])
            midi(0xB0 | channel, 7, part["volume"])
            midi(0xB0 | channel, 10, part["pan"])
            midi(0xB0 | channel, 91, 15)
        length = round(score["duration"] * 44100)
        output = np.zeros((length, 2), np.float32)
        left, right = np.zeros(1024, np.float32), np.zeros(1024, np.float32)
        buffers = Buffers(2, (Buffer * 2)(Buffer(1, 4096, left.ctypes.data), Buffer(1, 4096, right.ctypes.data)))
        events = sorted(score["events"], key=lambda e: (round(e["time"] * 44100), e["on"]))
        index = frame = 0
        while frame < length:
            while index < len(events) and round(events[index]["time"] * 44100) <= frame:
                event = events[index]
                midi((0x90 if event["on"] else 0x80) | event["channel"], event["pitch"], event["velocity"] if event["on"] else 0)
                index += 1
            next_frame = round(events[index]["time"] * 44100) if index < len(events) else length
            count = min(1024, length - frame, max(1, next_frame - frame))
            timestamp = Timestamp()
            timestamp.sample = frame
            timestamp.flags = 1
            flags = C.c_uint32(0)
            for b in buffers.buffers: b.size = count * 4
            check(au.AudioUnitRender(unit, C.byref(flags), C.byref(timestamp), 0, count, C.byref(buffers)))
            output[frame:frame + count, 0] = left[:count]
            output[frame:frame + count, 1] = right[:count]
            frame += count
        return output
    finally:
        au.AudioUnitUninitialize(unit)
        au.AudioComponentInstanceDispose(unit)


if __name__ == "__main__":
    score = json.loads(Path(sys.argv[1]).read_text())
    data = render(score)
    np.save(sys.argv[2], data)
    print(f"Rendered {len(data) / 44100:.2f} seconds, peak {np.max(np.abs(data)):.4f}")
