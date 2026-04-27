#!/usr/bin/env python3
"""
OSPFv2 MD5 Authentication Hash Extractor
Extracts the hash input (OSPF packet body) and captured MD5 digest
from a pcapng file for offline dictionary/brute-force cracking.

Usage:
    python3 ospf_extract_hashes.py <pcapng_file>

Output:
    Prints one hash per unique packet (deduplicated by router),
    in a format ready for offline cracking with hashcat or a custom script.
"""

import sys
import struct
import hashlib
import subprocess
import json


def parse_ospf_md5(frame_hex: str):
    """
    Parse a raw Ethernet frame and extract OSPFv2 MD5 auth components.
    Returns a dict with all relevant fields, or None if not MD5-auth OSPF.
    """
    try:
        raw = bytes.fromhex(frame_hex)
    except ValueError:
        return None

    # Minimum size check: Ethernet(14) + IP(20) + OSPF header(24)
    if len(raw) < 58:
        return None

    eth_len = 14

    # Parse IP header to get its length (handles IP options)
    ip_start = eth_len
    if len(raw) < ip_start + 20:
        return None
    ip_ihl = (raw[ip_start] & 0x0F) * 4  # IP header length in bytes
    ip_proto = raw[ip_start + 9]

    # Must be OSPF (protocol 89)
    if ip_proto != 89:
        return None

    src_ip = ".".join(str(b) for b in raw[ip_start + 12 : ip_start + 16])

    ospf_start = ip_start + ip_ihl
    ospf = raw[ospf_start:]

    if len(ospf) < 24:
        return None

    # OSPF header fields
    version   = ospf[0]
    pkt_type  = ospf[1]
    pkt_len   = struct.unpack("!H", ospf[2:4])[0]
    router_id = ".".join(str(b) for b in ospf[4:8])
    area_id   = ".".join(str(b) for b in ospf[8:12])
    au_type   = struct.unpack("!H", ospf[14:16])[0]

    # Only handle OSPFv2 with MD5 auth (AuType = 2)
    if version != 2 or au_type != 2:
        return None

    # Auth header layout (bytes 16-23 of OSPF header):
    # [0x00][0x00][Key ID][Auth Data Len][Seq Num (4 bytes)]
    key_id   = ospf[18]
    auth_len = ospf[19]
    seq_num  = struct.unpack("!I", ospf[20:24])[0]

    # The MD5 digest is appended immediately after the OSPF packet body
    if len(ospf) < pkt_len + auth_len:
        return None

    ospf_body   = bytes(ospf[:pkt_len])          # bytes hashed (with key appended)
    md5_digest  = ospf[pkt_len : pkt_len + auth_len]

    return {
        "src_ip":    src_ip,
        "router_id": router_id,
        "area_id":   area_id,
        "pkt_type":  pkt_type,
        "key_id":    key_id,
        "seq_num":   seq_num,
        "auth_len":  auth_len,
        "ospf_body": ospf_body.hex(),
        "md5_digest": md5_digest.hex(),
    }


def extract_hashes(pcapng_path: str):
    """
    Use tshark to export raw frame bytes, parse each frame for OSPF MD5 auth.
    Deduplicates by router_id (one hash entry per router is enough to crack).
    """
    try:
        result = subprocess.run(
            [
                "tshark",
                "-r", pcapng_path,
                "-T", "jsonraw",
                "-x",               # include raw bytes
            ],
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        print("Error: tshark not found. Install wireshark-common / tshark.")
        sys.exit(1)

    if result.returncode != 0:
        print(f"Error running tshark: {result.stderr.strip()}")
        sys.exit(1)

    try:
        frames = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        print(f"Error parsing tshark output: {e}")
        sys.exit(1)

    seen_routers = {}  # router_id -> parsed entry
    all_entries  = []

    for frame in frames:
        layers = frame.get("_source", {}).get("layers", {})
        frame_raw_list = layers.get("frame_raw")
        if not frame_raw_list:
            continue
        frame_hex = frame_raw_list[0]
        entry = parse_ospf_md5(frame_hex)
        if entry is None:
            continue

        all_entries.append(entry)

        # Keep only first occurrence per router for the summary
        if entry["router_id"] not in seen_routers:
            seen_routers[entry["router_id"]] = entry

    return all_entries, seen_routers


def pkt_type_name(t):
    return {1: "Hello", 2: "DBD", 3: "LSR", 4: "LSU", 5: "LSAck"}.get(t, f"Type{t}")


def print_results(all_entries, unique_routers):
    if not all_entries:
        print("No OSPFv2 MD5-authenticated packets found in the capture.")
        return

    print("=" * 70)
    print("  OSPFv2 MD5 Authentication Hash Extractor")
    print("=" * 70)
    print(f"  Total MD5-auth packets found : {len(all_entries)}")
    print(f"  Unique routers               : {len(unique_routers)}")
    print()

    print("-" * 70)
    print("  PER-ROUTER HASH SUMMARY (one entry per router)")
    print("-" * 70)

    for router_id, e in unique_routers.items():
        print(f"\n  Router ID  : {e['router_id']}")
        print(f"  Source IP  : {e['src_ip']}")
        print(f"  Area ID    : {e['area_id']}")
        print(f"  Pkt Type   : {pkt_type_name(e['pkt_type'])}")
        print(f"  Key ID     : {e['key_id']}")
        print(f"  Seq Num    : {e['seq_num']}")
        print(f"  Auth Len   : {e['auth_len']} bytes")
        print(f"  OSPF Body  : {e['ospf_body']}")
        print(f"  MD5 Digest : {e['md5_digest']}")

    print()
    print("=" * 70)
    print("  HOW TO CRACK WITH THIS SCRIPT")
    print("=" * 70)
    print("""
  The MD5 is computed as:
      MD5( OSPF_body_bytes  +  key_padded_to_16_bytes_with_null )

  To verify a candidate password, run:
      python3 ospf_extract_hashes.py <file> --crack <wordlist.txt>

  Or use the standalone check in Python:
      import hashlib
      ospf_body   = bytes.fromhex("<OSPF Body above>")
      target      = bytes.fromhex("<MD5 Digest above>")
      key         = b"yourguess".ljust(16, b'\\x00')[:16]
      result      = hashlib.md5(ospf_body + key).digest()
      print("Match!" if result == target else "No match")
""")


def crack_with_wordlist(unique_routers, wordlist_path: str):
    """Try every word in the wordlist against all unique router hashes."""
    targets = [
        (rid, bytes.fromhex(e["ospf_body"]), bytes.fromhex(e["md5_digest"]))
        for rid, e in unique_routers.items()
    ]

    print(f"\nCracking {len(targets)} hash(es) using wordlist: {wordlist_path}\n")

    found = {}
    tried = 0

    try:
        with open(wordlist_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                word = line.rstrip("\n")
                key_bytes = word.encode("utf-8")
                key_padded = (key_bytes + b"\x00" * 16)[:16]

                for router_id, ospf_body, target_digest in targets:
                    if router_id in found:
                        continue
                    digest = hashlib.md5(ospf_body + key_padded).digest()
                    if digest == target_digest:
                        found[router_id] = word
                        print(f"  ✅  Router {router_id}  →  key = '{word}'")

                tried += 1
                if tried % 100_000 == 0:
                    print(f"  ... {tried:,} words tried, {len(found)}/{len(targets)} cracked")

                if len(found) == len(targets):
                    break

    except FileNotFoundError:
        print(f"Error: wordlist file not found: {wordlist_path}")
        return

    print(f"\nFinished. Tried {tried:,} words.")
    if found:
        print("\nResults:")
        for rid, key in found.items():
            print(f"  Router {rid}  →  shared key = '{key}'")
    else:
        print("No keys found in this wordlist.")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    pcapng_path = sys.argv[1]

    # Optional: --crack <wordlist>
    crack_mode = False
    wordlist_path = None
    if len(sys.argv) >= 4 and sys.argv[2] == "--crack":
        crack_mode = True
        wordlist_path = sys.argv[3]

    print(f"\nReading capture file: {pcapng_path}\n")
    all_entries, unique_routers = extract_hashes(pcapng_path)
    print_results(all_entries, unique_routers)

    if crack_mode:
        crack_with_wordlist(unique_routers, wordlist_path)


if __name__ == "__main__":
    main()
