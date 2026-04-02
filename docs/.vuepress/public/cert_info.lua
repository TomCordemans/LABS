--------------------------------------------------------------------------------
-- cert_info.lua  –  Wireshark Lua post-dissector
-- Parses every X.509 certificate in a TLS Certificate handshake and adds a
-- detailed "X.509 Certificate Info" subtree to the Packet Details pane.
-- Validity is evaluated against the capture timestamp, not today's date.
--
-- Install:
--   Copy (or symlink) this file to your Wireshark personal plugins folder:
--     Linux / macOS : ~/.config/wireshark/plugins/cert_info.lua
--     Windows       : %APPDATA%\Wireshark\plugins\cert_info.lua
--   Reload without restart: Analyze → Reload Lua Plugins  (Ctrl+Shift+L)
--------------------------------------------------------------------------------

local proto = Proto("certinfo", "X.509 Certificate Info")

-- ── Proto fields (shown in Packet Details) ───────────────────────────────────
local pf = {
    cert       = ProtoField.string("certinfo.cert",       "Certificate"),
    subject    = ProtoField.string("certinfo.subject",    "Subject"),
    issuer     = ProtoField.string("certinfo.issuer",     "Issuer"),
    serial     = ProtoField.string("certinfo.serial",     "Serial Number"),
    sig_alg    = ProtoField.string("certinfo.sig_alg",    "Signature Algorithm"),
    key_info   = ProtoField.string("certinfo.key_info",   "Public Key"),
    not_before = ProtoField.string("certinfo.not_before", "Not Before"),
    not_after  = ProtoField.string("certinfo.not_after",  "Not After"),
    status     = ProtoField.string("certinfo.status",     "Status at Capture Time"),
    is_ca      = ProtoField.string("certinfo.is_ca",      "Certificate Authority"),
    san        = ProtoField.string("certinfo.san",        "Subject Alt Name"),
    fingerprint= ProtoField.string("certinfo.fingerprint","SHA-1 Fingerprint"),
}
proto.fields = pf

-- ── OID → human-readable name ─────────────────────────────────────────────────
local OID = {
    -- Distinguished Name attributes
    ["2.5.4.3"]               = "CN",
    ["2.5.4.4"]               = "SN",
    ["2.5.4.5"]               = "serialNumber",
    ["2.5.4.6"]               = "C",
    ["2.5.4.7"]               = "L",
    ["2.5.4.8"]               = "ST",
    ["2.5.4.9"]               = "street",
    ["2.5.4.10"]              = "O",
    ["2.5.4.11"]              = "OU",
    ["2.5.4.17"]              = "postalCode",
    ["2.5.4.20"]              = "phone",
    ["1.2.840.113549.1.9.1"]  = "emailAddress",
    -- Key algorithms
    ["1.2.840.113549.1.1.1"]  = "rsaEncryption",
    ["1.2.840.10045.2.1"]     = "ecPublicKey",
    ["1.3.101.110"]           = "X25519",
    ["1.3.101.112"]           = "Ed25519",
    -- Signature algorithms
    ["1.2.840.113549.1.1.4"]  = "md5WithRSAEncryption",
    ["1.2.840.113549.1.1.5"]  = "sha1WithRSAEncryption",
    ["1.2.840.113549.1.1.10"] = "rsaPSS",
    ["1.2.840.113549.1.1.11"] = "sha256WithRSAEncryption",
    ["1.2.840.113549.1.1.12"] = "sha384WithRSAEncryption",
    ["1.2.840.113549.1.1.13"] = "sha512WithRSAEncryption",
    ["1.2.840.10045.4.3.1"]   = "ecdsa-with-SHA224",
    ["1.2.840.10045.4.3.2"]   = "ecdsa-with-SHA256",
    ["1.2.840.10045.4.3.3"]   = "ecdsa-with-SHA384",
    ["1.2.840.10045.4.3.4"]   = "ecdsa-with-SHA512",
    -- EC named curves
    ["1.2.840.10045.3.1.7"]   = "P-256",
    ["1.3.132.0.34"]          = "P-384",
    ["1.3.132.0.35"]          = "P-521",
    -- X.509v3 extensions
    ["2.5.29.9"]              = "subjectDirectoryAttributes",
    ["2.5.29.14"]             = "subjectKeyIdentifier",
    ["2.5.29.15"]             = "keyUsage",
    ["2.5.29.17"]             = "subjectAltName",
    ["2.5.29.18"]             = "issuerAltName",
    ["2.5.29.19"]             = "basicConstraints",
    ["2.5.29.31"]             = "cRLDistributionPoints",
    ["2.5.29.32"]             = "certificatePolicies",
    ["2.5.29.35"]             = "authorityKeyIdentifier",
    ["2.5.29.37"]             = "extKeyUsage",
    -- Extended Key Usage values
    ["1.3.6.1.5.5.7.3.1"]    = "serverAuth",
    ["1.3.6.1.5.5.7.3.2"]    = "clientAuth",
    ["1.3.6.1.5.5.7.3.3"]    = "codeSigning",
    ["1.3.6.1.5.5.7.3.4"]    = "emailProtection",
    ["1.3.6.1.5.5.7.3.8"]    = "timeStamping",
    ["1.3.6.1.5.5.7.3.9"]    = "OCSPSigning",
}

-- ── ASN.1 / DER low-level helpers ─────────────────────────────────────────────

-- Read one byte from a ByteArray
local function B(ba, i)
    return ba:get_index(i)
end

-- Decode DER length at position pos; returns (length, next_pos)
local function read_len(ba, pos)
    local first = B(ba, pos)
    if first < 0x80 then
        return first, pos + 1
    end
    local n = first & 0x7F
    local len = 0
    for i = 1, n do
        len = len * 256 + B(ba, pos + i)
    end
    return len, pos + 1 + n
end

-- Read one TLV; returns (tag, content_start, content_len, next_tlv_pos)
local function tlv(ba, pos)
    local tag = B(ba, pos)
    local clen, cstart = read_len(ba, pos + 1)
    return tag, cstart, clen, cstart + clen
end

-- Decode a DER OID value field into dotted-decimal string
local function read_oid(ba, s, l)
    local first = B(ba, s)
    local out = math.floor(first / 40) .. "." .. (first % 40)
    local i = s + 1
    while i < s + l do
        local v = 0
        repeat
            local x = B(ba, i); i = i + 1
            v = v * 128 + (x & 0x7F)
            if (x & 0x80) == 0 then break end
        until i >= s + l
        out = out .. "." .. v
    end
    return out
end

-- Read printable bytes as a string (replaces non-printable with '?')
local function read_str(ba, s, l)
    local t = {}
    for i = s, s + l - 1 do
        local c = B(ba, i)
        t[#t + 1] = (c >= 32 and c < 127) and string.char(c) or "?"
    end
    return table.concat(t)
end

-- UTCTime  YYMMDDHHMMSSZ  →  "YYYY-MM-DD HH:MM:SS UTC"
local function parse_utctime(ba, s, l)
    local str = read_str(ba, s, l)
    local yy  = tonumber(str:sub(1, 2))
    local year = (yy >= 50) and (1900 + yy) or (2000 + yy)
    return string.format("%04d-%s-%s %s:%s:%s UTC",
        year, str:sub(3,4), str:sub(5,6), str:sub(7,8), str:sub(9,10), str:sub(11,12))
end

-- GeneralizedTime  YYYYMMDDHHMMSSZ  →  "YYYY-MM-DD HH:MM:SS UTC"
local function parse_gentime(ba, s, l)
    local str = read_str(ba, s, l)
    return string.format("%s-%s-%s %s:%s:%s UTC",
        str:sub(1,4), str:sub(5,6), str:sub(7,8),
        str:sub(9,10), str:sub(11,12), str:sub(13,14))
end

-- ── ASN.1 structure parsers ───────────────────────────────────────────────────

-- Parse an RDNSequence (Name) → "CN=foo, O=bar, C=US"
local function parse_name(ba, s, l)
    local parts, pos = {}, s
    while pos < s + l do
        local set_tag, set_cs, set_cl, set_next = tlv(ba, pos)
        if set_tag ~= 0x31 then break end          -- expect SET
        local sp = set_cs
        while sp < set_cs + set_cl do
            local seq_tag, seq_cs, seq_cl, seq_next = tlv(ba, sp)
            if seq_tag == 0x30 then                -- expect SEQUENCE
                local oid_tag, oid_cs, oid_cl, oid_next = tlv(ba, seq_cs)
                if oid_tag == 0x06 then
                    local attr = OID[read_oid(ba, oid_cs, oid_cl)] or read_oid(ba, oid_cs, oid_cl)
                    local _, val_cs, val_cl, _ = tlv(ba, oid_next)
                    parts[#parts + 1] = attr .. "=" .. read_str(ba, val_cs, val_cl)
                end
            end
            sp = seq_next
        end
        pos = set_next
    end
    return table.concat(parts, ", ")
end

-- Parse Validity SEQUENCE → (not_before_str, not_after_str)
local function parse_validity(ba, s, l)
    local t1, c1, l1, n1 = tlv(ba, s)
    local t2, c2, l2, _  = tlv(ba, n1)
    local nb = (t1 == 0x17) and parse_utctime(ba, c1, l1) or parse_gentime(ba, c1, l1)
    local na = (t2 == 0x17) and parse_utctime(ba, c2, l2) or parse_gentime(ba, c2, l2)
    return nb, na
end

-- Parse SubjectPublicKeyInfo content → e.g. "RSA 2048-bit" / "EC (P-256)"
local function parse_spki(ba, s, l)
    -- AlgorithmIdentifier SEQUENCE
    local atag, acs, acl, anext = tlv(ba, s)
    if atag ~= 0x30 then return "unknown" end
    local otag, ocs, ocl, onext = tlv(ba, acs)
    if otag ~= 0x06 then return "unknown" end
    local alg_oid  = read_oid(ba, ocs, ocl)

    if alg_oid == "1.2.840.113549.1.1.1" then          -- RSA
        local btag, bcs, bcl, _ = tlv(ba, anext)       -- BIT STRING
        if btag == 0x03 then
            -- skip unused-bits byte, parse inner SEQUENCE { INTEGER n, … }
            local itag, ics, icl, _ = tlv(ba, bcs + 1)
            if itag == 0x30 then
                local ntag, ncs, ncl, _ = tlv(ba, ics)
                if ntag == 0x02 then
                    local key_bytes = ncl - (B(ba, ncs) == 0x00 and 1 or 0)
                    return string.format("RSA %d-bit", key_bytes * 8)
                end
            end
        end
        return "RSA"

    elseif alg_oid == "1.2.840.10045.2.1" then         -- EC
        if onext < acs + acl then
            local ptag, pcs, pcl, _ = tlv(ba, onext)
            if ptag == 0x06 then
                local curve = read_oid(ba, pcs, pcl)
                return "EC (" .. (OID[curve] or curve) .. ")"
            end
        end
        return "EC"

    elseif alg_oid == "1.3.101.112" then return "Ed25519"
    elseif alg_oid == "1.3.101.110" then return "X25519"
    else
        return OID[alg_oid] or alg_oid
    end
end

-- Parse SubjectAltName extension content → array of "DNS:…" / "IP:…" strings
local function parse_san(ba, s, l)
    local tag, cs, cl, _ = tlv(ba, s)
    if tag ~= 0x30 then return {} end
    local sans, pos = {}, cs
    while pos < cs + cl do
        local gtag, gcs, gcl, gnext = tlv(ba, pos)
        if     gtag == 0x82 then  -- dNSName
            sans[#sans + 1] = "DNS:" .. read_str(ba, gcs, gcl)
        elseif gtag == 0x81 then  -- rfc822Name (e-mail)
            sans[#sans + 1] = "email:" .. read_str(ba, gcs, gcl)
        elseif gtag == 0x86 then  -- URI
            sans[#sans + 1] = "URI:" .. read_str(ba, gcs, gcl)
        elseif gtag == 0x87 then  -- iPAddress
            if gcl == 4 then
                sans[#sans + 1] = string.format("IP:%d.%d.%d.%d",
                    B(ba,gcs), B(ba,gcs+1), B(ba,gcs+2), B(ba,gcs+3))
            elseif gcl == 16 then
                local segs = {}
                for i = 0, 7 do
                    segs[i+1] = string.format("%04x",
                        B(ba, gcs+i*2)*256 + B(ba, gcs+i*2+1))
                end
                sans[#sans + 1] = "IP:" .. table.concat(segs, ":")
            end
        end
        pos = gnext
    end
    return sans
end

-- Parse BasicConstraints OCTET STRING content → bool is_ca
local function parse_basic_constraints(ba, s, l)
    local tag, cs, cl, _ = tlv(ba, s)
    if tag ~= 0x30 or cl == 0 then return false end
    local btag, bcs, bcl, _ = tlv(ba, cs)
    return (btag == 0x01 and bcl == 1 and B(ba, bcs) == 0xFF)
end

-- Parse the Extensions [3] wrapper → (sans_table, is_ca)
local function parse_extensions(ba, s, l)
    -- [3] wraps one SEQUENCE OF Extension
    local tag, cs, cl, _ = tlv(ba, s)
    if tag ~= 0x30 then return {}, false end
    local sans, is_ca, pos = {}, false, cs
    while pos < cs + cl do
        local etag, ecs, ecl, enext = tlv(ba, pos)
        if etag == 0x30 then
            -- Extension ::= SEQUENCE { extnID OID, critical BOOL opt, extnValue OCTET STRING }
            local oid_tag, oid_cs, oid_cl, oid_next = tlv(ba, ecs)
            if oid_tag == 0x06 then
                local ext_oid = read_oid(ba, oid_cs, oid_cl)
                local vpos = oid_next
                -- skip optional BOOLEAN (critical flag)
                local vtag, vcs, vcl, vnext = tlv(ba, vpos)
                if vtag == 0x01 then
                    vpos = vnext
                    vtag, vcs, vcl, vnext = tlv(ba, vpos)
                end
                if vtag == 0x04 then   -- OCTET STRING
                    if ext_oid == "2.5.29.17" then
                        sans = parse_san(ba, vcs, vcl)
                    elseif ext_oid == "2.5.29.19" then
                        is_ca = parse_basic_constraints(ba, vcs, vcl)
                    end
                end
            end
        end
        pos = enext
    end
    return sans, is_ca
end

-- ── Top-level certificate parser ──────────────────────────────────────────────
local function parse_cert(ba)
    local r = { sans = {}, is_ca = false }
    local ok, err = pcall(function()

        -- Certificate SEQUENCE
        local _, cert_cs, _, _ = tlv(ba, 0)

        -- TBSCertificate SEQUENCE
        local _, tbs_cs, tbs_cl, _ = tlv(ba, cert_cs)
        local pos     = tbs_cs
        local tbs_end = tbs_cs + tbs_cl

        -- version [0] EXPLICIT OPTIONAL
        if B(ba, pos) == 0xA0 then
            local _, _, _, vnext = tlv(ba, pos); pos = vnext
        end

        -- serialNumber INTEGER
        local tag, cs, cl, nx = tlv(ba, pos)
        if tag == 0x02 then
            local si = cs
            if B(ba, si) == 0x00 and cl > 1 then si = si + 1 end
            local h = {}
            for i = si, cs + cl - 1 do h[#h+1] = string.format("%02x", B(ba,i)) end
            r.serial = table.concat(h)
            pos = nx
        end

        -- signature (inner AlgorithmIdentifier)
        tag, cs, cl, nx = tlv(ba, pos)
        if tag == 0x30 then
            local ot, oc, ol, _ = tlv(ba, cs)
            if ot == 0x06 then
                local oid = read_oid(ba, oc, ol)
                r.sig_alg = OID[oid] or oid
            end
            pos = nx
        end

        -- issuer Name
        tag, cs, cl, nx = tlv(ba, pos)
        if tag == 0x30 then r.issuer = parse_name(ba, cs, cl); pos = nx end

        -- validity
        tag, cs, cl, nx = tlv(ba, pos)
        if tag == 0x30 then
            r.not_before, r.not_after = parse_validity(ba, cs, cl)
            pos = nx
        end

        -- subject Name
        tag, cs, cl, nx = tlv(ba, pos)
        if tag == 0x30 then r.subject = parse_name(ba, cs, cl); pos = nx end

        -- subjectPublicKeyInfo
        tag, cs, cl, nx = tlv(ba, pos)
        if tag == 0x30 then r.key_info = parse_spki(ba, cs, cl); pos = nx end

        -- skip optional issuerUniqueID [1] and subjectUniqueID [2]
        while pos < tbs_end do
            tag, cs, cl, nx = tlv(ba, pos)
            if tag == 0xA3 then   -- extensions [3]
                r.sans, r.is_ca = parse_extensions(ba, cs, cl)
            end
            pos = nx
        end

        -- SHA-1 fingerprint: compute over the whole cert DER
        -- (iterate all bytes of the ByteArray)
        -- Wireshark Lua has no built-in hash, so we derive a quick hex ID instead
        local len = ba:len()
        local fp_bytes = {}
        local step = math.max(1, math.floor(len / 20))
        for i = 0, len - 1, step do
            fp_bytes[#fp_bytes+1] = string.format("%02x", B(ba, i))
            if #fp_bytes >= 20 then break end
        end
        r.fingerprint_hint = "(use tls.handshake.certificate in hex for full fingerprint)"

    end)
    if not ok then r.error = tostring(err) end
    return r
end

-- ── Validity check ────────────────────────────────────────────────────────────
-- Compares cert date strings ("YYYY-MM-DD HH:MM:SS UTC") against capture time.
-- pinfo.abs_ts tostring → "seconds.microseconds"
local function validity_status(nb, na, abs_ts)
    local secs = tonumber(tostring(abs_ts):match("^(%d+)"))
    if not secs then return "unknown (no timestamp)" end
    -- os.date("!…") formats in UTC
    local cap = os.date("!%Y-%m-%d %H:%M:%S UTC", secs)
    if cap < nb then return "NOT YET VALID at capture" end
    if cap > na then return "EXPIRED at capture"       end
    return "VALID at capture"
end

-- ── Post-dissector registration ───────────────────────────────────────────────
local tls_cert_f = Field.new("tls.handshake.certificate")
local tls_type_f = Field.new("tls.handshake.type")

function proto.dissector(tvb, pinfo, tree)
    -- Only run on TLS Certificate handshake messages (type = 11)
    local found = false
    for _, ti in ipairs({tls_type_f()}) do
        if tonumber(ti.value) == 11 then found = true; break end
    end
    if not found then return end

    local certs = {tls_cert_f()}
    if #certs == 0 then return end

    local range = tvb(0, 1)   -- anchor to byte 0 (display only, no specific bytes)
    local root  = tree:add(proto, range,
        string.format("X.509 Certificate Info  [%d certificate(s) in chain]", #certs))

    for idx, cert_fi in ipairs(certs) do
        local ba = cert_fi.value
        if not ba then goto continue end

        local r   = parse_cert(ba)
        local sub = root:add(pf.cert, range,
            string.format("[%d]  %s  (%s)",
                idx,
                r.subject or "(parse error)",
                r.is_ca and "CA" or "end-entity"))

        if r.error then
            sub:add_expert_info(PI_MALFORMED, PI_ERROR, "Parse error: " .. r.error)
        else
            if r.subject    then sub:add(pf.subject,    range, r.subject)    end
            if r.issuer     then sub:add(pf.issuer,     range, r.issuer)     end
            if r.serial     then sub:add(pf.serial,     range, r.serial)     end
            if r.sig_alg    then sub:add(pf.sig_alg,    range, r.sig_alg)    end
            if r.key_info   then sub:add(pf.key_info,   range, r.key_info)   end
                            sub:add(pf.is_ca,       range, r.is_ca and "Yes" or "No")
            if r.not_before then sub:add(pf.not_before, range, r.not_before) end
            if r.not_after  then sub:add(pf.not_after,  range, r.not_after)  end

            if r.not_before and r.not_after then
                local status = validity_status(r.not_before, r.not_after, pinfo.abs_ts)
                local status_item = sub:add(pf.status, range, status)
                -- colour the status item to make it stand out
                if status:find("EXPIRED") then
                    status_item:add_expert_info(PI_SECURITY, PI_WARN,
                        "Certificate was EXPIRED at the time of this capture")
                elseif status:find("NOT YET") then
                    status_item:add_expert_info(PI_SECURITY, PI_WARN,
                        "Certificate was not yet valid at the time of this capture")
                end
            end

            for _, san in ipairs(r.sans) do
                sub:add(pf.san, range, san)
            end
        end

        ::continue::
    end
end

register_postdissector(proto)

-- ── Friendly startup message ──────────────────────────────────────────────────
print("[cert_info.lua] X.509 Certificate Info post-dissector loaded.")
