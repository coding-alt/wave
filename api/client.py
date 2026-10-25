#!/usr/bin/env python3
import base64, json, uuid, urllib.parse, urllib.request
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

BASE = "http://49.232.234.212"
KEY = b"ILOVERADIO666666"


def aes_enc(text: str) -> str:
    c = AES.new(KEY, AES.MODE_ECB)
    return base64.b64encode(c.encrypt(pad(text.encode(), 16))).decode()


def aes_dec(b64: str) -> str:
    c = AES.new(KEY, AES.MODE_ECB)
    return unpad(c.decrypt(base64.b64decode(b64)), 16).decode()


def post(path, extra=None, uid=None, imei=None):
    body = {
        "imei": imei or str(uuid.uuid4()),
        "uid": uid or str(uuid.uuid4()),
        "device": "2",
        "qd": "2002",
        "version": "1.2.5",
        "model": "Andriod",
        "channelid": "Andriod",
    }
    if extra:
        body.update(extra)
    sign = aes_enc(json.dumps(body, ensure_ascii=False, separators=(",", ":")))
    data = urllib.parse.urlencode({"sign": sign}).encode()
    req = urllib.request.Request(BASE + path, data=data, method="POST")
    req.add_header("Accept", "application/json;charset=UTF-8")
    req.add_header("Content-Type", "application/x-www-form-urlencoded; charset=utf-8")
    with urllib.request.urlopen(req, timeout=15) as f:
        raw = f.read().decode()
    j = json.loads(raw)
    d = j.get("data")
    if isinstance(d, str) and d:
        try:
            j["data"] = json.loads(aes_dec(d))
        except Exception as e:
            j["data_decrypt_error"] = str(e)
    return j


if __name__ == "__main__":
    r = post("/radio/getAllCategory")
    print(json.dumps(r, ensure_ascii=False, indent=2)[:3000])
