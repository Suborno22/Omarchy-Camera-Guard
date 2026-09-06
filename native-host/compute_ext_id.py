#!/usr/bin/env python3
"""
Chrome computes an unpacked extension's ID as: SHA-256 of the DER-encoded
public key, take the first 16 bytes, map each nibble (0-15) to a letter
(a-p). Given the same DER public key file used in manifest.json's "key"
field, this reproduces that ID so the native-messaging host manifest can
be written for it ahead of time.

Usage: compute_ext_id.py pubkey.der
"""
import sys
import hashlib

with open(sys.argv[1], "rb") as f:
    der = f.read()

digest_hex = hashlib.sha256(der).hexdigest()[:32]
ext_id = "".join(chr(ord("a") + int(c, 16)) for c in digest_hex)
print(ext_id)
