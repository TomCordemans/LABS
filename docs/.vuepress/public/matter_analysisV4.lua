--------------------------------------------------------------------------------
-- matter_analysis.lua  (v4 - self-contained)
--
-- Matter (CSA Connected Home over IP) analysis for Wireshark.
--
-- WHAT CHANGED IN v4
--   Fixes a hard crash (segfault) in Wireshark 4.4 / 4.6 when loading a capture
--   that contains Matter CASE/PASE handshakes.
--   Cause: unnamed TLV integers were added to the 64-bit field matterx.tlv.uint
--   (and matterx.tlv.int) as plain Lua numbers.  Since Wireshark 4.4, a 64-bit
--   ProtoField only accepts UInt64/Int64 values; the type check raises a Lua
--   error from INSIDE Wireshark's C exception handler (TRY block) of
--   TreeItem:add().  pcall() catches the Lua error, but Wireshark's internal
--   exception stack is left corrupted, and the next packet crashes in
--   except_pop().  Lesson: pcall() cannot make a failing TreeItem:add() safe.
--   v4 converts every value to the exact type the target field expects, so
--   TreeItem:add() is never called with a mismatched value.
--
-- WHAT CHANGED IN v3
--   v1/v2 were postdissectors that read fields from Wireshark's built-in
--   "matter" dissector.  That dissector is registered for "Decode As" only, so
--   on most builds it never runs on UDP 5540 and the script produced nothing.
--   v3 parses the Matter message header itself and registers directly on
--   UDP 5540, so it has no external dependencies at all.
--
-- WHAT IT DOES
--   * Parses the Matter message header and exchange header from raw bytes.
--   * Full Matter TLV decoding of the plaintext Secure Channel handshakes
--     (PASE: PBKDFParamRequest/Response, Pake1/2/3; CASE: Sigma1/2/3, Resume;
--      plus the non-TLV StatusReport).
--   * Session tracking, role attribution, MRP acknowledgement analysis.
--   * Inference of ENCRYPTED Interaction Model messages from direction, size
--     and ordering -- always labelled as inference, never as observation.
--   * Matter DNS-SD decoding (_matterc._udp / _matter._tcp, subtypes, TXT).
--   * Expert info for state transitions and security findings.
--   * Tools > Matter > Capture Analysis Report   (timeline + summary)
--   * Tools > Matter > Diagnostics               (why am I seeing nothing?)
--
-- LUA COMPATIBILITY
--   Restricted to the Lua 5.1 subset so it loads on every Wireshark build:
--   no goto/labels, no bitwise operators, no // division, no bit library.
--
-- Nothing here decrypts traffic.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 0.  Protocols and preferences
--------------------------------------------------------------------------------

-- Main protocol: owns every field and expert, dissects UDP 5540.
local matterx = Proto("matterx", "Matter Analysis")

-- Thin companion protocol: postdissector used only to read the mDNS
-- dissector's output for DNS-SD analysis.
local matterxsd = Proto("matterxsd", "Matter DNS-SD Analysis")

matterx.prefs.port = Pref.uint("Matter UDP port", 5540,
    "UDP port carrying Matter traffic (default 5540). Change requires a restart.")

matterx.prefs.infer = Pref.bool("Infer encrypted Interaction Model messages", true,
    "Classify encrypted payloads by direction/size/order. Results are INFERENCE, "
 .. "not observation, and carry an explicit confidence level.")

matterx.prefs.dnssd = Pref.bool("Interpret Matter DNS-SD records", true,
    "Decode _matterc._udp / _matter._tcp names, subtypes and TXT keys.")

matterx.prefs.callbuiltin = Pref.bool("Also run the built-in Matter dissector", true,
    "If Wireshark ships a 'matter' dissector, invoke it too so its own tree "
 .. "appears alongside this analysis.")

matterx.prefs.stdout_report = Pref.bool("Print report on tshark draw", false,
    "Under tshark with -q, print the capture report to stdout.")

--------------------------------------------------------------------------------
-- 1.  Constants
--------------------------------------------------------------------------------

-- Secure Channel opcodes (protocol ID 0x0000).
-- Source: src/protocols/secure_channel/Constants.h in the Matter SDK.
local SC_OPCODE = {
    [0x00] = "MsgCounterSyncReq",       [0x01] = "MsgCounterSyncRsp",
    [0x10] = "StandaloneAck (MRP)",
    [0x20] = "PBKDFParamRequest (PASE)", [0x21] = "PBKDFParamResponse (PASE)",
    [0x22] = "PASE_Pake1",              [0x23] = "PASE_Pake2",
    [0x24] = "PASE_Pake3",
    [0x30] = "CASE_Sigma1",             [0x31] = "CASE_Sigma2",
    [0x32] = "CASE_Sigma3",             [0x33] = "CASE_Sigma2Resume",
    [0x40] = "StatusReport",            [0x50] = "ICD_CheckIn",
}

local PROTOCOL_ID = {
    [0x0000] = "Secure Channel",
    [0x0001] = "Interaction Model",
    [0x0002] = "BDX (Bulk Data Exchange)",
    [0x0003] = "User Directed Commissioning",
    [0x0004] = "For Testing",
}

local SESSION_TYPE = { [0] = "Unicast session", [1] = "Group session" }

local DSIZ = {
    [0] = "0 - no destination node ID",
    [1] = "1 - 64-bit destination node ID",
    [2] = "2 - 16-bit destination group ID",
    [3] = "3 - reserved",
}

local SC_GENERAL_CODE = {
    [0]="SUCCESS",[1]="FAILURE",[2]="BAD_PRECONDITION",[3]="OUT_OF_RANGE",
    [4]="BAD_REQUEST",[5]="UNSUPPORTED",[6]="UNEXPECTED",[7]="RESOURCE_EXHAUSTED",
    [8]="BUSY",[9]="TIMEOUT",[10]="CONTINUE",[11]="ABORTED",
    [12]="INVALID_ARGUMENT",[13]="NOT_FOUND",[14]="ALREADY_EXISTS",
    [15]="PERMISSION_DENIED",[16]="DATA_LOSS",
}

local SC_PROTOCOL_CODE = {
    [0x0000]="Success/Continue", [0x0001]="NoSharedTrustRoots",
    [0x0002]="InvalidParameter", [0x0003]="CloseSession",
    [0x0004]="Busy",             [0xFFFF]="GeneralFailure",
}

local CM_MODE = {
    [0] = "0 - Not in commissioning mode",
    [1] = "1 - Open, original setup code (basic)",
    [2] = "2 - Open, dynamic passcode (OpenCommissioningWindow)",
}

local PAIRING_HINT_BITS = {
    [0]="Power Cycle", [1]="Device Manufacturer URL", [2]="Administrator",
    [3]="Settings menu on the Node", [4]="Custom Instruction", [5]="Device Manual",
    [6]="Press Reset Button", [7]="Press Reset Button with application of power",
    [8]="Press Reset Button for N seconds", [9]="Press Reset Button until light blinks",
    [10]="Press Reset Button for N seconds with application of power",
    [11]="Press Reset Button until light blinks with application of power",
    [12]="Press Reset Button N times", [13]="Press Setup Button",
}

local DEVICE_TYPE = {
    [0x000A]="Door Lock", [0x000E]="Aggregator", [0x0015]="Contact Sensor",
    [0x0016]="Root Node", [0x002B]="Fan",
    [0x0100]="On/Off Light", [0x0101]="Dimmable Light",
    [0x0103]="On/Off Light Switch", [0x0106]="Light Sensor",
    [0x0107]="Occupancy Sensor", [0x010A]="On/Off Plug-in Unit",
    [0x010B]="Dimmable Plug-in Unit", [0x010C]="Color Temperature Light",
    [0x010D]="Extended Color Light", [0x0202]="Window Covering",
    [0x0301]="Thermostat", [0x0302]="Temperature Sensor", [0x0307]="Humidity Sensor",
}

-- Device types for which a no-argument On/Off command is a plausible candidate.
local ONOFF_CAPABLE = {
    [0x0100]=true,[0x0101]=true,[0x010A]=true,
    [0x010B]=true,[0x010C]=true,[0x010D]=true,
}

--------------------------------------------------------------------------------
-- 2.  ProtoFields
--------------------------------------------------------------------------------

local pf = {}

-- ---- status / analysis ----------------------------------------------------
pf.status       = ProtoField.string("matterx.status", "Analysis status")
pf.message      = ProtoField.string("matterx.message", "Message")
pf.session_kind = ProtoField.string("matterx.session.kind", "Session kind")
pf.role         = ProtoField.string("matterx.role", "Sender role")
pf.encrypted    = ProtoField.bool  ("matterx.encrypted", "Payload encrypted")
pf.pt_len       = ProtoField.uint32("matterx.plaintext_len",
                                    "Plaintext protocol payload length", base.DEC)
pf.ack_only     = ProtoField.bool  ("matterx.standalone_ack", "Standalone MRP ACK")

-- ---- message header -------------------------------------------------------
pf.h_flags      = ProtoField.uint8 ("matterx.hdr.flags", "Message Flags", base.HEX)
pf.h_version    = ProtoField.uint8 ("matterx.hdr.version", "Version", base.DEC)
pf.h_has_src    = ProtoField.bool  ("matterx.hdr.has_source", "Source Node ID present")
pf.h_dsiz       = ProtoField.uint8 ("matterx.hdr.dsiz", "DSIZ", base.DEC, DSIZ)
pf.h_session    = ProtoField.uint16("matterx.hdr.session_id", "Session ID", base.HEX)
pf.h_secflags   = ProtoField.uint8 ("matterx.hdr.security_flags", "Security Flags", base.HEX)
pf.h_sesstype   = ProtoField.uint8 ("matterx.hdr.session_type", "Session Type",
                                    base.DEC, SESSION_TYPE)
pf.h_privacy    = ProtoField.bool  ("matterx.hdr.privacy", "Privacy enabled")
pf.h_control    = ProtoField.bool  ("matterx.hdr.control", "Control message")
pf.h_msgext     = ProtoField.bool  ("matterx.hdr.msg_extensions", "Message extensions")
pf.h_counter    = ProtoField.uint32("matterx.hdr.counter", "Message Counter", base.HEX)
pf.h_src        = ProtoField.uint64("matterx.hdr.src_node", "Source Node ID", base.HEX)
pf.h_dst        = ProtoField.uint64("matterx.hdr.dst_node", "Destination Node ID", base.HEX)
pf.h_dstgrp     = ProtoField.uint16("matterx.hdr.dst_group", "Destination Group ID", base.HEX)
pf.h_len        = ProtoField.uint32("matterx.hdr.length", "Message header length", base.DEC)

-- ---- exchange header ------------------------------------------------------
pf.x_flags      = ProtoField.uint8 ("matterx.exch.flags", "Exchange Flags", base.HEX)
pf.x_initiator  = ProtoField.bool  ("matterx.exch.initiator", "Initiator")
pf.x_ack        = ProtoField.bool  ("matterx.exch.ack", "Carries acknowledgement")
pf.x_reliable   = ProtoField.bool  ("matterx.exch.reliability", "Requires acknowledgement")
pf.x_secext     = ProtoField.bool  ("matterx.exch.secured_ext", "Secured extensions")
pf.x_vendor     = ProtoField.bool  ("matterx.exch.has_vendor", "Vendor protocol")
pf.x_opcode     = ProtoField.uint8 ("matterx.exch.opcode", "Protocol Opcode", base.HEX)
pf.x_opname     = ProtoField.string("matterx.exch.opcode_name", "Opcode name")
pf.x_id         = ProtoField.uint16("matterx.exch.exchange_id", "Exchange ID", base.HEX)
pf.x_vendorid   = ProtoField.uint16("matterx.exch.vendor_id", "Protocol Vendor ID", base.HEX)
pf.x_protocol   = ProtoField.uint16("matterx.exch.protocol_id", "Protocol ID",
                                    base.HEX, PROTOCOL_ID)
pf.x_ackctr     = ProtoField.uint32("matterx.exch.ack_counter",
                                    "Acknowledged Message Counter", base.HEX)

-- ---- inference ------------------------------------------------------------
pf.inf_msg      = ProtoField.string("matterx.inferred.message", "Inferred message")
pf.inf_cluster  = ProtoField.string("matterx.inferred.cluster", "Inferred cluster")
pf.inf_conf     = ProtoField.string("matterx.inferred.confidence", "Confidence")
pf.inf_basis    = ProtoField.string("matterx.inferred.basis", "Basis")
pf.inf_note     = ProtoField.string("matterx.inferred.note", "Note")

-- ---- Secure Channel payload ----------------------------------------------
pf.init_random  = ProtoField.bytes ("matterx.sc.initiator_random", "initiatorRandom")
pf.resp_random  = ProtoField.bytes ("matterx.sc.responder_random", "responderRandom")
pf.init_sid     = ProtoField.uint16("matterx.sc.initiator_session_id",
                                    "initiatorSessionId", base.HEX)
pf.resp_sid     = ProtoField.uint16("matterx.sc.responder_session_id",
                                    "responderSessionId", base.HEX)

pf.sp_idle      = ProtoField.uint32("matterx.sp.idle_interval",
                                    "SESSION_IDLE_INTERVAL (ms)", base.DEC)
pf.sp_active    = ProtoField.uint32("matterx.sp.active_interval",
                                    "SESSION_ACTIVE_INTERVAL (ms)", base.DEC)
pf.sp_thresh    = ProtoField.uint32("matterx.sp.active_threshold",
                                    "SESSION_ACTIVE_THRESHOLD (ms)", base.DEC)
pf.sp_dm_rev    = ProtoField.uint16("matterx.sp.data_model_revision",
                                    "DataModelRevision", base.DEC)
pf.sp_im_rev    = ProtoField.uint16("matterx.sp.interaction_model_revision",
                                    "InteractionModelRevision", base.DEC)
pf.sp_spec      = ProtoField.uint32("matterx.sp.specification_version",
                                    "SpecificationVersion", base.HEX)
pf.sp_spec_str  = ProtoField.string("matterx.sp.specification_version_str",
                                    "Specification version")
pf.sp_maxpaths  = ProtoField.uint16("matterx.sp.max_paths_per_invoke",
                                    "MaxPathsPerInvoke", base.DEC)

pf.passcode_id  = ProtoField.uint16("matterx.pase.passcode_id", "passcodeId", base.DEC)
pf.has_pbkdf    = ProtoField.bool  ("matterx.pase.has_pbkdf_params", "hasPBKDFParameters")
pf.pbkdf_iter   = ProtoField.uint32("matterx.pase.pbkdf_iterations",
                                    "PBKDF2 iterations", base.DEC)
pf.pbkdf_salt   = ProtoField.bytes ("matterx.pase.pbkdf_salt", "PBKDF2 salt")
pf.pake_pA      = ProtoField.bytes ("matterx.pase.pA", "pA (SPAKE2+ initiator element)")
pf.pake_pB      = ProtoField.bytes ("matterx.pase.pB", "pB (SPAKE2+ responder element)")
pf.pake_cA      = ProtoField.bytes ("matterx.pase.cA", "cA (initiator confirmation)")
pf.pake_cB      = ProtoField.bytes ("matterx.pase.cB", "cB (responder confirmation)")

pf.dest_id      = ProtoField.bytes ("matterx.case.destination_id",
                        "destinationId (HMAC over IPK, root pubkey, fabric, node)")
pf.eph_pub      = ProtoField.bytes ("matterx.case.eph_pubkey", "Ephemeral P-256 public key")
pf.enc2         = ProtoField.bytes ("matterx.case.encrypted2",
                        "encrypted2 (responder NOC + ICAC + signature)")
pf.enc3         = ProtoField.bytes ("matterx.case.encrypted3",
                        "encrypted3 (initiator NOC + ICAC + signature)")
pf.resume_id    = ProtoField.bytes ("matterx.case.resumption_id", "resumptionID")
pf.resume_mic   = ProtoField.bytes ("matterx.case.resume_mic", "Resume MIC")
pf.case_full    = ProtoField.bool  ("matterx.case.full_handshake",
                                    "Full CASE handshake (no resumption)")

pf.sr_general   = ProtoField.uint16("matterx.status.general_code", "GeneralCode",
                                    base.DEC, SC_GENERAL_CODE)
pf.sr_protocol  = ProtoField.uint32("matterx.status.protocol_id", "ProtocolId", base.HEX)
pf.sr_code      = ProtoField.uint16("matterx.status.protocol_code", "ProtocolCode",
                                    base.HEX, SC_PROTOCOL_CODE)

-- ---- generic TLV ----------------------------------------------------------
pf.tlv_cont     = ProtoField.none  ("matterx.tlv.container", "Container")
pf.tlv_raw      = ProtoField.none  ("matterx.tlv.element", "TLV element")
pf.tlv_uint     = ProtoField.uint64("matterx.tlv.uint", "Unsigned integer", base.DEC)
pf.tlv_int      = ProtoField.int64 ("matterx.tlv.int", "Signed integer", base.DEC)
pf.tlv_bytes    = ProtoField.bytes ("matterx.tlv.bytes", "Octet string")
pf.tlv_str      = ProtoField.string("matterx.tlv.string", "UTF-8 string")
pf.tlv_bool     = ProtoField.bool  ("matterx.tlv.bool", "Boolean")
pf.tlv_null     = ProtoField.none  ("matterx.tlv.null", "Null")
pf.tlv_float    = ProtoField.double("matterx.tlv.float", "Floating point")

-- ---- DNS-SD ---------------------------------------------------------------
pf.sd_service   = ProtoField.string("matterx.dnssd.service", "Matter service")
pf.sd_vid       = ProtoField.uint16("matterx.dnssd.vendor_id", "Vendor ID", base.HEX)
pf.sd_pid       = ProtoField.uint16("matterx.dnssd.product_id", "Product ID", base.HEX)
pf.sd_dt        = ProtoField.uint32("matterx.dnssd.device_type", "Device type", base.HEX)
pf.sd_dt_name   = ProtoField.string("matterx.dnssd.device_type_name", "Device type name")
pf.sd_dn        = ProtoField.string("matterx.dnssd.device_name",
                                    "Device name (unauthenticated)")
pf.sd_disc      = ProtoField.uint16("matterx.dnssd.discriminator",
                                    "Long discriminator", base.DEC)
pf.sd_cm        = ProtoField.uint8 ("matterx.dnssd.commissioning_mode",
                                    "Commissioning mode", base.DEC, CM_MODE)
pf.sd_ph        = ProtoField.uint32("matterx.dnssd.pairing_hint", "Pairing hint", base.HEX)
pf.sd_ph_bit    = ProtoField.string("matterx.dnssd.pairing_hint_action", "Suggested action")
pf.sd_pi        = ProtoField.string("matterx.dnssd.pairing_instruction",
                                    "Pairing instruction")
pf.sd_tcp       = ProtoField.uint8 ("matterx.dnssd.tcp_support", "TCP support flags", base.HEX)
pf.sd_tcp_txt   = ProtoField.string("matterx.dnssd.tcp_support_desc", "TCP support")
pf.sd_sii       = ProtoField.uint32("matterx.dnssd.sii",
                                    "Session idle interval hint (ms)", base.DEC)
pf.sd_sai       = ProtoField.uint32("matterx.dnssd.sai",
                                    "Session active interval hint (ms)", base.DEC)
pf.sd_sat       = ProtoField.uint32("matterx.dnssd.sat",
                                    "Session active threshold hint (ms)", base.DEC)
pf.sd_icd       = ProtoField.uint8 ("matterx.dnssd.icd", "ICD operating mode", base.DEC)
pf.sd_cfid      = ProtoField.uint64("matterx.dnssd.compressed_fabric_id",
                                    "Compressed fabric ID", base.HEX)
pf.sd_node      = ProtoField.uint64("matterx.dnssd.node_id",
                                    "Operational node ID", base.HEX)
pf.sd_subtype   = ProtoField.string("matterx.dnssd.subtype", "Browse subtype")
pf.sd_goodbye   = ProtoField.bool  ("matterx.dnssd.goodbye", "Goodbye (TTL=0) record")

do
    local list = {}
    for _, v in pairs(pf) do list[#list + 1] = v end
    matterx.fields = list
end
matterxsd.fields = {}

--------------------------------------------------------------------------------
-- 3.  Expert info
--------------------------------------------------------------------------------

local ei = {}
ei.window_closed = ProtoExpert.new("matterx.ei.window_closed",
    "Commissioning window closed (CM=0)", expert.group.SEQUENCE, expert.severity.CHAT)
ei.window_open = ProtoExpert.new("matterx.ei.window_open",
    "Device advertising as commissionable", expert.group.SEQUENCE, expert.severity.CHAT)
ei.goodbye = ProtoExpert.new("matterx.ei.goodbye",
    "mDNS goodbye packet (TTL=0) - immediate cache invalidation",
    expert.group.SEQUENCE, expert.severity.CHAT)
ei.test_vendor = ProtoExpert.new("matterx.ei.test_vendor",
    "CSA test Vendor ID - development firmware, must not ship",
    expert.group.SECURITY, expert.severity.WARN)
ei.pbkdf_min = ProtoExpert.new("matterx.ei.pbkdf_min",
    "PBKDF2 iteration count at the specification minimum (1000)",
    expert.group.SECURITY, expert.severity.NOTE)
ei.pase_done = ProtoExpert.new("matterx.ei.pase_done",
    "PASE session established", expert.group.SEQUENCE, expert.severity.CHAT)
ei.case_done = ProtoExpert.new("matterx.ei.case_done",
    "CASE session established", expert.group.SEQUENCE, expert.severity.CHAT)
ei.sc_failure = ProtoExpert.new("matterx.ei.sc_failure",
    "Secure Channel StatusReport reports failure",
    expert.group.RESPONSE_CODE, expert.severity.ERROR)
ei.full_case = ProtoExpert.new("matterx.ei.full_case",
    "Full CASE handshake - session resumption not used",
    expert.group.PROTOCOL, expert.severity.NOTE)
ei.spec_skew = ProtoExpert.new("matterx.ei.spec_skew",
    "Peers report different Matter specification versions",
    expert.group.PROTOCOL, expert.severity.NOTE)
ei.inferred = ProtoExpert.new("matterx.ei.inferred",
    "Message identity is inferred from size/direction/order, not observed",
    expert.group.UNDECODED, expert.severity.CHAT)
ei.malformed = ProtoExpert.new("matterx.ei.malformed",
    "Truncated or malformed Matter data", expert.group.MALFORMED, expert.severity.WARN)

do
    local list = {}
    for _, v in pairs(ei) do list[#list + 1] = v end
    matterx.experts = list
end

--------------------------------------------------------------------------------
-- 4.  Helpers (Lua 5.1 safe)
--------------------------------------------------------------------------------

local function rshift(v, n)   return math.floor(v / (2 ^ n)) end
local function band_bit(v, n) return (rshift(v, n) % 2) == 1 end

local function spec_version_str(v)
    return string.format("%d.%d.%d.%d",
        rshift(v, 24) % 256, rshift(v, 16) % 256, rshift(v, 8) % 256, v % 256)
end

local function tonum(v)
    if type(v) == "number" then return v end
    return tonumber(tostring(v))
end

-- ---------------------------------------------------------------------------
-- Type-exact value conversion for TreeItem:add().
--
-- IMPORTANT (Wireshark 4.4+): never rely on pcall() around TreeItem:add().
-- A type mismatch raises a Lua error inside a C TRY block; pcall() swallows
-- the error but Wireshark's exception stack stays corrupted -> segfault later.
-- Always hand each field a value of exactly the right type instead.
-- ---------------------------------------------------------------------------
local U32_MAX = 4294967295

-- Any integer-ish value (Lua number or UInt64) -> UInt64, for 64-bit uint fields.
local function as_u64(v)
    if type(v) == "number" then return UInt64.new(v) end
    return v
end

-- Any integer-ish value (Lua number or Int64) -> Int64, for 64-bit int fields.
local function as_i64(v)
    if type(v) == "number" then return Int64.new(v) end
    return v
end

-- Value -> Lua number if it fits a 32-bit unsigned field, else nil.
local function as_u32(v)
    if type(v) ~= "number" then
        if v == nil then return nil end
        local n = tonumber(tostring(v))
        if not n then return nil end
        v = n
    end
    if v < 0 or v > U32_MAX or v ~= math.floor(v) then return nil end
    return math.floor(v)
end

local function uint64_from_hex16(s)
    if type(s) ~= "string" or #s ~= 16 then return nil end
    local hi, lo = tonumber(s:sub(1, 8), 16), tonumber(s:sub(9, 16), 16)
    if not hi or not lo then return nil end
    return UInt64.new(lo, hi)
end

-- Field.new() raises on unknown fields; never let that abort script loading.
local function safe_field(name)
    local ok, f = pcall(Field.new, name)
    if ok then return f end
    return nil
end

local function all(fx)
    if not fx then return {} end
    local ok, res = pcall(function() return { fx() } end)
    if ok then return res end
    return {}
end

--------------------------------------------------------------------------------
-- 5.  Matter TLV decoder (Core Specification, Appendix A)
--------------------------------------------------------------------------------

local TLV_TAG_LEN = {[0]=0,[1]=1,[2]=2,[3]=4,[4]=2,[5]=4,[6]=6,[7]=8}

local TLV_TYPE = {
    [0x00]={"int",1},[0x01]={"int",2},[0x02]={"int",4},[0x03]={"int",8},
    [0x04]={"uint",1},[0x05]={"uint",2},[0x06]={"uint",4},[0x07]={"uint",8},
    [0x08]={"bool",0},[0x09]={"bool",0},
    [0x0A]={"float",4},[0x0B]={"float",8},
    [0x0C]={"utf8",1},[0x0D]={"utf8",2},[0x0E]={"utf8",4},[0x0F]={"utf8",8},
    [0x10]={"bytes",1},[0x11]={"bytes",2},[0x12]={"bytes",4},[0x13]={"bytes",8},
    [0x14]={"null",0},
    [0x15]={"struct",0},[0x16]={"array",0},[0x17]={"list",0},[0x18]={"end",0},
}

local MAX_DEPTH = 12

local function le_uint(tvbr, off, len)
    if len <= 4 then return tvbr(off, len):le_uint() end
    return tvbr(off, len):le_uint64()
end

-- Measure the TLV element at `off`.  nil on truncation or illegal control byte.
local function tlv_element_info(tvbr, off)
    local limit = tvbr:len()
    if off < 0 or off >= limit then return nil end

    local ctrl  = tvbr(off, 1):uint()
    local tctrl = rshift(ctrl, 5)
    local etype = ctrl % 32
    local d     = TLV_TYPE[etype]
    if not d then return nil end

    local kind, nb = d[1], d[2]
    if kind == "end" then
        return { kind = "end", etype = etype, hdr = off, next = off + 1 }
    end

    local tl = TLV_TAG_LEN[tctrl] or 0
    local p  = off + 1
    if p + tl > limit then return nil end

    local tag
    if tl > 0 then tag = le_uint(tvbr, p, tl); p = p + tl end

    if kind == "struct" or kind == "array" or kind == "list" then
        return { kind=kind, etype=etype, tctrl=tctrl, tag=tag,
                 hdr=off, valoff=p, container=true }
    end

    if kind == "utf8" or kind == "bytes" then
        if p + nb > limit then return nil end
        local n = tonum(le_uint(tvbr, p, nb)) or 0
        local vo = p + nb
        if n < 0 or vo + n > limit then return nil end
        return { kind=kind, etype=etype, tctrl=tctrl, tag=tag,
                 hdr=off, valoff=vo, vallen=n, next=vo + n }
    end

    if p + nb > limit then return nil end
    return { kind=kind, etype=etype, tctrl=tctrl, tag=tag,
             hdr=off, valoff=p, vallen=nb, next=p + nb }
end

-- Offset just past the element at `off`, descending through containers.
local function tlv_skip(tvbr, off)
    local e = tlv_element_info(tvbr, off)
    if not e then return nil end
    if not e.container then return e.next end

    local p, depth, limit = e.valoff, 1, tvbr:len()
    while depth > 0 do
        if p >= limit then return nil end
        local ee = tlv_element_info(tvbr, p)
        if not ee then return nil end
        if ee.kind == "end" then depth = depth - 1; p = ee.next
        elseif ee.container then depth = depth + 1; p = ee.valoff
        else p = ee.next end
    end
    return p
end

-- Map context tag -> element descriptor for members of the outer structure.
local function scan_top_level(tvbr)
    local out = {}
    pcall(function()
        local outer = tlv_element_info(tvbr, 0)
        local off   = (outer and outer.container) and outer.valoff or 0
        local limit = tvbr:len()
        while off < limit do
            local e = tlv_element_info(tvbr, off)
            if not e or e.kind == "end" then return end
            if e.tctrl == 1 and type(e.tag) == "number" then out[e.tag] = e end
            local nxt = tlv_skip(tvbr, off)
            if not nxt or nxt <= off then return end
            off = nxt
        end
    end)
    return out
end

--------------------------------------------------------------------------------
-- 5a.  TLV schemas
--------------------------------------------------------------------------------

local ctx  -- per-packet context, set during handshake dissection

local function post_spec_version(tree, _, value, tvbr, off, len)
    tree:add(pf.sp_spec_str, tvbr(off, len), spec_version_str(value)):set_generated()
    if ctx then ctx.spec_version = value end
end

local function post_iterations(_, item, value)
    value = as_u32(value)
    if value and value <= 1000 then
        item:add_proto_expert_info(ei.pbkdf_min,
            "PBKDF2 iterations = " .. tostring(value)
            .. " (specification permits 1000..100000; 1000 is the floor)")
    end
end

local SCHEMA_SESSION_PARAMS = {
    [1]={name="SESSION_IDLE_INTERVAL",    pf=pf.sp_idle},
    [2]={name="SESSION_ACTIVE_INTERVAL",  pf=pf.sp_active},
    [3]={name="SESSION_ACTIVE_THRESHOLD", pf=pf.sp_thresh},
    [4]={name="DataModelRevision",        pf=pf.sp_dm_rev},
    [5]={name="InteractionModelRevision", pf=pf.sp_im_rev},
    [6]={name="SpecificationVersion",     pf=pf.sp_spec, post=post_spec_version},
    [7]={name="MaxPathsPerInvoke",        pf=pf.sp_maxpaths},
}

local SCHEMA_PBKDF_PARAMS = {
    [1]={name="iterations", pf=pf.pbkdf_iter, post=post_iterations},
    [2]={name="salt",       pf=pf.pbkdf_salt},
}

local SCHEMAS = {
    [0x20]={name="PBKDFParamRequest", fields={
        [1]={name="initiatorRandom",        pf=pf.init_random},
        [2]={name="initiatorSessionId",     pf=pf.init_sid},
        [3]={name="passcodeId",             pf=pf.passcode_id},
        [4]={name="hasPBKDFParameters",     pf=pf.has_pbkdf},
        [5]={name="initiatorSessionParams", sub=SCHEMA_SESSION_PARAMS}}},
    [0x21]={name="PBKDFParamResponse", fields={
        [1]={name="initiatorRandom",        pf=pf.init_random},
        [2]={name="responderRandom",        pf=pf.resp_random},
        [3]={name="responderSessionId",     pf=pf.resp_sid},
        [4]={name="pbkdf_parameters",       sub=SCHEMA_PBKDF_PARAMS},
        [5]={name="responderSessionParams", sub=SCHEMA_SESSION_PARAMS}}},
    [0x22]={name="PASE_Pake1", fields={[1]={name="pA", pf=pf.pake_pA}}},
    [0x23]={name="PASE_Pake2", fields={
        [1]={name="pB", pf=pf.pake_pB}, [2]={name="cB", pf=pf.pake_cB}}},
    [0x24]={name="PASE_Pake3", fields={[1]={name="cA", pf=pf.pake_cA}}},
    [0x30]={name="CASE_Sigma1", fields={
        [1]={name="initiatorRandom",        pf=pf.init_random},
        [2]={name="initiatorSessionId",     pf=pf.init_sid},
        [3]={name="destinationId",          pf=pf.dest_id},
        [4]={name="initiatorEphPubKey",     pf=pf.eph_pub},
        [5]={name="initiatorSessionParams", sub=SCHEMA_SESSION_PARAMS},
        [6]={name="resumptionID",           pf=pf.resume_id},
        [7]={name="initiatorResumeMIC",     pf=pf.resume_mic}}},
    [0x31]={name="CASE_Sigma2", fields={
        [1]={name="responderRandom",        pf=pf.resp_random},
        [2]={name="responderSessionId",     pf=pf.resp_sid},
        [3]={name="responderEphPubKey",     pf=pf.eph_pub},
        [4]={name="encrypted2",             pf=pf.enc2},
        [5]={name="responderSessionParams", sub=SCHEMA_SESSION_PARAMS}}},
    [0x32]={name="CASE_Sigma3", fields={[1]={name="encrypted3", pf=pf.enc3}}},
    [0x33]={name="CASE_Sigma2Resume", fields={
        [1]={name="resumptionID",           pf=pf.resume_id},
        [2]={name="sigma2ResumeMIC",        pf=pf.resume_mic},
        [3]={name="responderSessionID",     pf=pf.resp_sid},
        [4]={name="responderSessionParams", sub=SCHEMA_SESSION_PARAMS}}},
}

--------------------------------------------------------------------------------
-- 5b.  TLV tree rendering
--------------------------------------------------------------------------------

-- NOTE: the pcall() here is only a last-resort guard against Lua-side errors.
-- It does NOT make a type-mismatched TreeItem:add() safe in Wireshark 4.4+
-- (see the header).  Callers must pass correctly typed values.
local function safe_add(tree, field, range, value, fallback_text)
    local ok, item
    if value == nil then ok, item = pcall(function() return tree:add(field, range) end)
    else ok, item = pcall(function() return tree:add(field, range, value) end) end
    if ok and item then return item end
    local it = tree:add(pf.tlv_raw, range)
    it:set_text(fallback_text or "TLV element (unrenderable)")
    return it
end

local function render_scalar(tvbr, e, tree, ent, label)
    local field = ent and ent.pf or nil
    local named = (field ~= nil)

    if e.kind == "bool" then
        local val  = (e.etype == 0x09)
        local text = string.format("%s: %s", label, tostring(val))
        local item = safe_add(tree, field or pf.tlv_bool,
                              tvbr(e.hdr, e.valoff - e.hdr), val and 1 or 0, text)
        if item and not named then item:set_text(text) end
        return item
    end

    if e.kind == "null" then
        local item = tree:add(pf.tlv_null, tvbr(e.hdr, e.valoff - e.hdr))
        item:set_text(label .. ": null")
        return item
    end

    if e.kind == "uint" or e.kind == "int" or e.kind == "float" then
        local r = tvbr(e.valoff, e.vallen)
        local value, add_field, add_value
        if e.kind == "uint" then
            value = le_uint(tvbr, e.valoff, e.vallen)   -- number or UInt64
            -- Named schema fields are 8/16/32-bit: they need a Lua number.
            local n32 = field and as_u32(value) or nil
            if n32 then
                add_field, add_value = field, n32
            else
                -- Generic 64-bit field: it needs a UInt64 (crash cause in v3).
                add_field, add_value, named = pf.tlv_uint, as_u64(value), false
            end
        elseif e.kind == "int" then
            value = (e.vallen <= 4) and r:le_int() or r:le_int64()
            add_field, add_value, named = pf.tlv_int, as_i64(value), false
        else
            value = r:le_float()
            add_field, add_value, named = pf.tlv_float, value, false
        end
        local text = string.format("%s: %s", label, tostring(value))
        local item = safe_add(tree, add_field, r, add_value, text)
        if item and not named then item:set_text(text) end
        if item and ent and ent.post then
            pcall(ent.post, tree, item, value, tvbr, e.valoff, e.vallen)
        end
        return item
    end

    if e.kind == "utf8" then
        local r    = tvbr(e.valoff, e.vallen)
        local sval = (e.vallen > 0) and r:string() or ""
        local text = string.format("%s: \"%s\"", label, sval)
        local item = safe_add(tree, field or pf.tlv_str, r, sval, text)
        if item and not named then item:set_text(text) end
        return item
    end

    if e.kind == "bytes" then
        local r    = tvbr(e.valoff, e.vallen)
        local text = string.format("%s: %d bytes", label, e.vallen)
        local item = safe_add(tree, field or pf.tlv_bytes, r, nil, text)
        if item then
            if named then item:append_text(string.format("  (%d bytes)", e.vallen))
            else item:set_text(text) end
        end
        return item
    end
    return nil
end

local decode_tlv
decode_tlv = function(tvbr, off, tree, schema, depth)
    local limit = tvbr:len()
    if depth > MAX_DEPTH then
        tree:add_proto_expert_info(ei.malformed,
            "TLV nesting deeper than " .. MAX_DEPTH .. " levels; aborting")
        return limit
    end

    while off < limit do
        local e = tlv_element_info(tvbr, off)
        if not e then
            tree:add_proto_expert_info(ei.malformed,
                string.format("Malformed or truncated TLV at offset %d", off))
            return limit
        end
        if e.kind == "end" then return e.next end

        local ent
        if schema and e.tctrl == 1 and type(e.tag) == "number" then ent = schema[e.tag] end
        local label = (ent and ent.name)
                      or (e.tag and ("Tag " .. tostring(e.tag))) or "(anonymous)"

        local nxt
        if e.container then
            local sub = tree:add(pf.tlv_cont, tvbr(e.hdr, 1))
            sub:set_text(string.format("%s [%s]", label, string.upper(e.kind)))
            nxt = decode_tlv(tvbr, e.valoff, sub, ent and ent.sub or nil, depth + 1)
            pcall(function() sub:set_len(nxt - e.hdr) end)
        else
            render_scalar(tvbr, e, tree, ent, label)
            nxt = e.next
        end

        if not nxt or nxt <= off then return limit end
        off = nxt
    end
    return off
end

--------------------------------------------------------------------------------
-- 6.  Matter header parsers
--
-- Message Flags bits:  7..4 Version | 3 reserved | 2 S(source present) | 1..0 DSIZ
-- Security Flags bits: 7 P(privacy) | 6 C(control) | 5 MX(extensions) | 1..0 SessionType
--------------------------------------------------------------------------------

local function parse_message_header(tvb)
    local len = tvb:len()
    if len < 8 then return nil, "shorter than the 8-byte Matter message header" end

    local h = {}
    h.flags       = tvb(0, 1):uint()
    h.version     = rshift(h.flags, 4) % 16
    h.has_src     = band_bit(h.flags, 2)
    h.dsiz        = h.flags % 4
    h.session_id  = tvb(1, 2):le_uint()
    h.sec_flags   = tvb(3, 1):uint()
    h.session_type= h.sec_flags % 4
    h.privacy     = band_bit(h.sec_flags, 7)
    h.control     = band_bit(h.sec_flags, 6)
    h.msg_ext     = band_bit(h.sec_flags, 5)
    h.counter     = tvb(4, 4):le_uint()

    local off = 8
    if h.has_src then
        if off + 8 > len then return nil, "truncated Source Node ID" end
        h.src_off = off; off = off + 8
    end
    if h.dsiz == 1 then
        if off + 8 > len then return nil, "truncated Destination Node ID" end
        h.dst_off = off; off = off + 8
    elseif h.dsiz == 2 then
        if off + 2 > len then return nil, "truncated Destination Group ID" end
        h.grp_off = off; off = off + 2
    elseif h.dsiz == 3 then
        return nil, "DSIZ=3 is reserved"
    end

    h.hdr_len   = off
    h.unsecured = (h.session_id == 0 and h.session_type == 0)
    return h
end

local function parse_exchange_header(tvb, off)
    local len = tvb:len()
    if off + 4 > len then return nil, "truncated exchange header" end

    local e = {}
    e.off         = off
    e.flags       = tvb(off, 1):uint()
    e.initiator   = band_bit(e.flags, 0)
    e.ack         = band_bit(e.flags, 1)
    e.reliability = band_bit(e.flags, 2)
    e.sec_ext     = band_bit(e.flags, 3)
    e.vendor      = band_bit(e.flags, 4)
    e.opcode      = tvb(off + 1, 1):uint()
    e.exchange_id = tvb(off + 2, 2):le_uint()

    local p = off + 4
    if e.vendor then
        if p + 2 > len then return nil, "truncated Protocol Vendor ID" end
        e.vendor_off = p; p = p + 2
    end
    if p + 2 > len then return nil, "truncated Protocol ID" end
    e.proto_off  = p
    e.protocol_id = tvb(p, 2):le_uint()
    p = p + 2
    if e.ack then
        if p + 4 > len then return nil, "truncated Acknowledged Message Counter" end
        e.ack_off = p; p = p + 4
    end

    e.payload_off = p
    e.hdr_len     = p - off
    return e
end

--------------------------------------------------------------------------------
-- 7.  Per-capture state
--------------------------------------------------------------------------------

local state

local function new_state()
    return {
        convs = {}, sessions = {}, events = {},
        device = {}, fabric = {}, specs = {},
        first_ts = nil, last_ts = nil,
        counts = { udp5540 = 0, udp5353 = 0, parsed = 0,
                   unsecured = 0, secured = 0, badhdr = 0, dnssd = 0 },
    }
end

function matterx.init() state = new_state() end
state = new_state()

local function conv_key(pinfo)
    local a, b = tostring(pinfo.net_src), tostring(pinfo.net_dst)
    if a < b then return a .. "|" .. b end
    return b .. "|" .. a
end

local function get_conv(pinfo)
    local k = conv_key(pinfo)
    local c = state.convs[k]
    if not c then
        c = { key=k, commissioner=nil, device=nil, pase_step=0,
              case_count=0, commissioning_complete=false }
        state.convs[k] = c
    end
    return c
end

local function add_event(pinfo, phase, label, detail)
    local t = tonum(pinfo.rel_ts) or 0
    state.events[pinfo.number] = {
        frame=pinfo.number, ts=t, src=tostring(pinfo.net_src),
        dst=tostring(pinfo.net_dst), phase=phase, label=label, detail=detail }
    if not state.first_ts or t < state.first_ts then state.first_ts = t end
    if not state.last_ts  or t > state.last_ts  then state.last_ts  = t end
end

--------------------------------------------------------------------------------
-- 8.  Commissioning sequence model (INFERENCE ONLY)
--
-- The Interaction Model payloads are AES-128-CCM encrypted and this script has
-- no key material.  Only direction, size and ordering are observable.  The step
-- list mirrors the Matter SDK AutoCommissioner; sizes are sanity bounds.
--------------------------------------------------------------------------------

local PASE_STEPS = {
    {dir="I", msg="ReadRequest (commissioning info, multi-path)",
     cluster="Basic Information 0x0028 / General Commissioning 0x0030 / Network Commissioning 0x0031 / Descriptor 0x001D",
     min=40, max=250, conf="medium"},
    {dir="R", msg="ReportData (attribute values)",
     cluster="(same as read paths)", min=60, max=900, conf="medium"},
    {dir="I", msg="ReadRequest #2 or StatusResponse (chunk solicitation)",
     cluster="(commissioning info)", min=10, max=200, conf="low"},
    {dir="R", msg="ReportData (attribute values)",
     cluster="(same as read paths)", min=60, max=900, conf="medium"},
    {dir="I", msg="InvokeRequest: ArmFailSafe",
     cluster="General Commissioning 0x0030", min=20, max=70, conf="high"},
    {dir="R", msg="InvokeResponse: ArmFailSafeResponse {errorCode, debugText}",
     cluster="General Commissioning 0x0030", min=25, max=70, conf="high"},
    {dir="I", msg="InvokeRequest: SetRegulatoryConfig",
     cluster="General Commissioning 0x0030", min=25, max=90, conf="high"},
    {dir="R", msg="InvokeResponse: SetRegulatoryConfigResponse",
     cluster="General Commissioning 0x0030", min=25, max=70, conf="high"},
    {dir="I", msg="InvokeRequest: CertificateChainRequest (PAI)",
     cluster="Operational Credentials 0x003E", min=20, max=60, conf="high"},
    {dir="R", msg="InvokeResponse: CertificateChainResponse - PAI certificate",
     cluster="Operational Credentials 0x003E", min=250, max=900, conf="high"},
    {dir="I", msg="InvokeRequest: CertificateChainRequest (DAC)",
     cluster="Operational Credentials 0x003E", min=20, max=60, conf="high"},
    {dir="R", msg="InvokeResponse: CertificateChainResponse - DAC certificate",
     cluster="Operational Credentials 0x003E", min=250, max=900, conf="high"},
    {dir="I", msg="InvokeRequest: AttestationRequest (32-byte nonce)",
     cluster="Operational Credentials 0x003E", min=45, max=110, conf="high"},
    {dir="R", msg="InvokeResponse: AttestationResponse - attestation elements (incl. Certification Declaration) + signature",
     cluster="Operational Credentials 0x003E", min=300, max=1400, conf="high"},
    {dir="I", msg="InvokeRequest: CSRRequest (32-byte nonce)",
     cluster="Operational Credentials 0x003E", min=45, max=110, conf="high"},
    {dir="R", msg="InvokeResponse: CSRResponse - NOCSR elements + signature (private key stays on device)",
     cluster="Operational Credentials 0x003E", min=200, max=700, conf="high"},
    {dir="I", msg="InvokeRequest: AddTrustedRootCertificate (RCAC)",
     cluster="Operational Credentials 0x003E", min=150, max=450, conf="high"},
    {dir="R", msg="InvokeResponse: status-only SUCCESS",
     cluster="Operational Credentials 0x003E", min=20, max=60, conf="high"},
    {dir="I", msg="InvokeRequest: AddNOC (NOC + ICAC + IPK + CASEAdminSubject + adminVendorId)",
     cluster="Operational Credentials 0x003E", min=300, max=900, conf="high"},
    {dir="R", msg="InvokeResponse: NOCResponse {statusCode, fabricIndex, debugText}",
     cluster="Operational Credentials 0x003E", min=25, max=80, conf="high"},
}

local function match_pase_step(conv, dir, pt_len)
    local start = conv.pase_step + 1
    for i = start, math.min(start + 3, #PASE_STEPS) do
        local s = PASE_STEPS[i]
        if s.dir == dir then
            conv.pase_step = i
            local conf, note = s.conf, nil
            if pt_len < s.min or pt_len > s.max then
                conf = "low"
                note = string.format(
                    "payload %d bytes is outside the %d..%d range expected here; "
                 .. "the sequence model may be out of step with this capture",
                    pt_len, s.min, s.max)
            end
            return s, conf, note
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- 9.  Secure Channel payload dissection
--------------------------------------------------------------------------------

local function dissect_status_report(tvbr, tree)
    -- StatusReport is a fixed little-endian struct, NOT TLV.
    if tvbr:len() < 8 then
        tree:add_proto_expert_info(ei.malformed, "StatusReport shorter than 8 bytes")
        return nil
    end
    local sub = tree:add(matterx, tvbr(0, 8))
    sub:set_text("StatusReport (fixed struct, not TLV)")
    local gc, pid, pc = tvbr(0,2):le_uint(), tvbr(2,4):le_uint(), tvbr(6,2):le_uint()
    sub:add(pf.sr_general,  tvbr(0, 2), gc)
    sub:add(pf.sr_protocol, tvbr(2, 4), pid)
    sub:add(pf.sr_code,     tvbr(6, 2), pc)
    if gc ~= 0 and gc ~= 10 then
        sub:add_proto_expert_info(ei.sc_failure,
            string.format("GeneralCode %d (%s), ProtocolCode 0x%04X",
                gc, SC_GENERAL_CODE[gc] or "unknown", pc))
    end
    return gc
end

-- Record session IDs advertised inside a handshake message.
local function record_session_ids(opcode, tvbr, pinfo)
    local kind
    if opcode == 0x20 or opcode == 0x21 then kind = "PASE"
    elseif opcode == 0x30 or opcode == 0x31 or opcode == 0x33 then kind = "CASE"
    else return end

    local tags = scan_top_level(tvbr)
    local which = { 2, 3 }
    for _, t in ipairs(which) do
        local e = tags[t]
        if e and e.kind == "uint" and e.vallen then
            local sid = tonum(le_uint(tvbr, e.valoff, e.vallen))
            if sid and sid ~= 0 and not state.sessions[sid] then
                state.sessions[sid] = { kind = kind, first_frame = pinfo.number }
            end
        end
    end
end

local function dissect_sc_payload(pinfo, tree, opcode, tvbr, conv)
    if tvbr:len() == 0 then return end

    if opcode == 0x40 then
        local gc = dissect_status_report(tvbr, tree)
        if gc == 0 then
            if conv.pending == "PASE" then
                tree:add_proto_expert_info(ei.pase_done, "PASE handshake succeeded")
                add_event(pinfo, "PASE",
                    "StatusReport SUCCESS - PASE session established",
                    "Encrypted commissioning channel is now available")
                conv.pending = nil
            elseif conv.pending == "CASE" then
                conv.case_count = conv.case_count + 1
                tree:add_proto_expert_info(ei.case_done,
                    "CASE handshake #" .. conv.case_count .. " succeeded")
                add_event(pinfo, "CASE",
                    "StatusReport SUCCESS - CASE session #" .. conv.case_count
                    .. " established",
                    "Mutually certificate-authenticated operational session")
                conv.pending = nil
            end
        end
        return
    end

    pcall(record_session_ids, opcode, tvbr, pinfo)

    local schema = SCHEMAS[opcode]
    local sub = tree:add(matterx, tvbr)
    sub:set_text((schema and schema.name or "Application payload") .. " (Matter TLV)")
    if not schema then sub:append_text("  [no schema for this opcode; generic decode]") end

    local off = 0
    local outer = tlv_element_info(tvbr, 0)
    if outer and outer.container then off = outer.valoff end

    ctx = { spec_version = nil }
    local dok, derr = pcall(decode_tlv, tvbr, off, sub,
                            schema and schema.fields or nil, 0)
    if not dok then
        sub:add_proto_expert_info(ei.malformed, "TLV decode failed: " .. tostring(derr))
    end

    if ctx and ctx.spec_version then
        local who = tostring(pinfo.net_src)
        state.specs[who] = { version = ctx.spec_version, frame = pinfo.number }
        for addr, rec in pairs(state.specs) do
            if addr ~= who and rec.version ~= ctx.spec_version then
                sub:add_proto_expert_info(ei.spec_skew, string.format(
                    "%s reports %s, %s reports %s", who,
                    spec_version_str(ctx.spec_version), addr,
                    spec_version_str(rec.version)))
                break
            end
        end
    end
    ctx = nil

    -- Sigma1 tags 6/7 distinguish full CASE from resumption.
    if opcode == 0x30 then
        local tags = scan_top_level(tvbr)
        local has_resume = (tags[6] ~= nil) or (tags[7] ~= nil)
        sub:add(pf.case_full, has_resume and 0 or 1):set_generated()
        if not has_resume then
            sub:add_proto_expert_info(ei.full_case,
                "Sigma1 carries no resumptionID/Resume1MIC, so a full CASE handshake "
             .. "runs (two signature verifications rather than a MIC check)")
        end
    end

    -- Timeline + handshake-state tracking.
    if opcode == 0x20 then
        conv.pending = "PASE"
        conv.commissioner = tostring(pinfo.net_src)
        conv.device = tostring(pinfo.net_dst)
        add_event(pinfo, "PASE", "PBKDFParamRequest",
            "Commissioner opens SPAKE2+ (passcode-authenticated) handshake")
    elseif opcode == 0x21 then
        add_event(pinfo, "PASE", "PBKDFParamResponse",
            "Device returns PBKDF salt and iteration count (public by design)")
    elseif opcode == 0x22 then
        add_event(pinfo, "PASE", "PASE_Pake1", "Initiator SPAKE2+ element pA")
    elseif opcode == 0x23 then
        add_event(pinfo, "PASE", "PASE_Pake2", "Responder element pB + confirmation cB")
    elseif opcode == 0x24 then
        add_event(pinfo, "PASE", "PASE_Pake3", "Initiator confirmation cA")
    elseif opcode == 0x30 then
        conv.pending = "CASE"
        conv.commissioner = conv.commissioner or tostring(pinfo.net_src)
        conv.device = conv.device or tostring(pinfo.net_dst)
        add_event(pinfo, "CASE", "CASE_Sigma1",
            "destinationId HMAC addresses the node without revealing fabric or node ID")
    elseif opcode == 0x31 then
        add_event(pinfo, "CASE", "CASE_Sigma2",
            "Responder NOC + ICAC + signature, already encrypted under S2K")
    elseif opcode == 0x32 then
        add_event(pinfo, "CASE", "CASE_Sigma3",
            "Initiator NOC + ICAC + signature, encrypted under S3K")
    elseif opcode == 0x33 then
        add_event(pinfo, "CASE", "CASE_Sigma2Resume", "Session resumption in use")
    end
end

--------------------------------------------------------------------------------
-- 10.  Encrypted payload inference
--------------------------------------------------------------------------------

local MIC = 16

local function analyse_encrypted(pinfo, tree, h, tvb, conv)
    local pt = tvb:len() - h.hdr_len - MIC

    local sess = state.sessions[h.session_id]
    local kind = sess and sess.kind or "unknown"

    tree:add(pf.session_kind, kind):set_generated()
    tree:add(pf.encrypted, 1):set_generated()

    if pt < 0 then
        tree:add_proto_expert_info(ei.malformed,
            "payload too short to hold the message header plus a 16-byte MIC")
        return nil
    end
    tree:add(pf.pt_len, pt):set_generated()

    -- Standalone MRP ACK: 6-byte exchange header + 4-byte ack counter.
    if pt == 10 then
        tree:add(pf.ack_only, 1):set_generated()
        tree:add(pf.message, "Standalone MRP ACK (secured)"):set_generated()
        return "Standalone MRP ACK"
    end

    if not matterx.prefs.infer then
        tree:add(pf.status, "inference disabled in preferences"):set_generated()
        return nil
    end

    local is_init = (conv.commissioner ~= nil)
                    and (tostring(pinfo.net_src) == conv.commissioner)
    local dir = is_init and "I" or "R"

    local isub = tree:add(matterx)
    isub:set_text("Inferred Interaction Model message  [INFERENCE - NOT OBSERVED]")
    isub:add_proto_expert_info(ei.inferred,
        "The payload is AES-128-CCM encrypted. Cluster, command and attribute IDs "
     .. "are inside the ciphertext. The identification below derives only from "
     .. "message direction, plaintext length and position in the sequence.")
    isub:add(pf.inf_basis, string.format("direction=%s, plaintext=%d bytes, session=%s",
        is_init and "commissioner->device" or "device->commissioner", pt, kind))
        :set_generated()

    local label

    if kind == "PASE" then
        local step, conf, note = match_pase_step(conv, dir, pt)
        if step then
            label = step.msg
            isub:add(pf.inf_msg, step.msg):set_generated()
            isub:add(pf.inf_cluster, step.cluster):set_generated()
            isub:add(pf.inf_conf, conf):set_generated()
            if note then isub:add(pf.inf_note, note):set_generated() end
            isub:append_text("  ->  " .. step.msg .. "  (confidence: " .. conf .. ")")
            add_event(pinfo, "COMMISSIONING", step.msg,
                string.format("%s | %d B plaintext | confidence %s",
                    step.cluster, pt, conf))
        else
            label = "Interaction Model message (unclassified)"
            isub:add(pf.inf_msg, label):set_generated()
            isub:add(pf.inf_conf, "none"):set_generated()
            isub:add(pf.inf_note,
                "Beyond the modelled commissioning sequence, or direction did not "
             .. "match any upcoming step"):set_generated()
        end

    elseif kind == "CASE" then
        if is_init then
            if not conv.commissioning_complete then
                label = "InvokeRequest: CommissioningComplete"
                isub:add(pf.inf_msg, label):set_generated()
                isub:add(pf.inf_cluster, "General Commissioning 0x0030"):set_generated()
                isub:add(pf.inf_conf,
                    (pt >= 20 and pt <= 60) and "high" or "low"):set_generated()
                isub:add(pf.inf_note,
                    "First initiator-side Invoke on the first CASE session after "
                 .. "credential installation; Matter requires CommissioningComplete "
                 .. "to travel over CASE, never PASE"):set_generated()
                conv.expect_cc_response = true
                add_event(pinfo, "COMMISSIONING", label,
                    "Two-phase commit: proves the new credentials work before the "
                 .. "fail-safe is disarmed")
            else
                label = "InvokeRequest: application command"
                isub:add(pf.inf_msg, label):set_generated()
                isub:add(pf.inf_conf, "medium"):set_generated()
                local hint = "no-argument command (plaintext " .. pt .. " B)"
                local dt = state.device.device_type
                if dt and ONOFF_CAPABLE[dt] then
                    hint = hint .. "; candidate: On/Off cluster 0x0006 On (0x00) / "
                        .. "Off (0x01) / Toggle (0x02) - indistinguishable from ciphertext"
                    isub:add(pf.inf_cluster, "On/Off 0x0006 (candidate)"):set_generated()
                end
                isub:add(pf.inf_note, hint):set_generated()
                add_event(pinfo, "CONTROL", label, hint)
            end
        else
            if conv.expect_cc_response then
                label = "InvokeResponse: CommissioningCompleteResponse"
                isub:add(pf.inf_msg, label):set_generated()
                isub:add(pf.inf_cluster, "General Commissioning 0x0030"):set_generated()
                isub:add(pf.inf_conf, "high"):set_generated()
                conv.expect_cc_response = false
                conv.commissioning_complete = true
                state.commissioned_frame = pinfo.number
                state.commissioned_ts = tonum(pinfo.rel_ts) or 0
                add_event(pinfo, "COMMISSIONING",
                    "CommissioningCompleteResponse - COMMISSIONING COMPLETE",
                    "Fail-safe disarmed; the node is now a fabric member")
            else
                label = "InvokeResponse"
                isub:add(pf.inf_msg, label):set_generated()
                isub:add(pf.inf_conf, "medium"):set_generated()
                isub:add(pf.inf_note, (pt <= 45)
                    and "size consistent with a status-only response (no response command)"
                    or  "size consistent with a response command carrying fields")
                    :set_generated()
                add_event(pinfo, "CONTROL", label, pt .. " B plaintext")
            end
        end
        if label then isub:append_text("  ->  " .. label) end

    else
        label = "Interaction Model message"
        isub:add(pf.inf_msg, label):set_generated()
        isub:add(pf.inf_conf, "none"):set_generated()
        isub:add(pf.inf_note,
            "No handshake for this session ID appeared in the capture, so the "
         .. "session type is unknown"):set_generated()
    end

    return label
end

--------------------------------------------------------------------------------
-- 11.  Main dissector (registered on UDP 5540)
--------------------------------------------------------------------------------

-- Handle to Wireshark's own Matter dissector, if this build has one.
local builtin_matter = nil
do
    local ok, h = pcall(Dissector.get, "matter")
    if ok then builtin_matter = h end
end

local function render_message_header(tvb, h, tree)
    local sub = tree:add(matterx, tvb(0, h.hdr_len))
    sub:set_text(string.format("Message Header (%d bytes)", h.hdr_len))

    local f = sub:add(pf.h_flags, tvb(0, 1), h.flags)
    f:add(pf.h_version,  tvb(0, 1), h.version)
    f:add(pf.h_has_src,  tvb(0, 1), h.has_src and 1 or 0)
    f:add(pf.h_dsiz,     tvb(0, 1), h.dsiz)

    local sid = sub:add(pf.h_session, tvb(1, 2), h.session_id)
    if h.unsecured then sid:append_text("  (unsecured session)") end

    local sf = sub:add(pf.h_secflags, tvb(3, 1), h.sec_flags)
    sf:add(pf.h_sesstype, tvb(3, 1), h.session_type)
    sf:add(pf.h_privacy,  tvb(3, 1), h.privacy and 1 or 0)
    sf:add(pf.h_control,  tvb(3, 1), h.control and 1 or 0)
    sf:add(pf.h_msgext,   tvb(3, 1), h.msg_ext and 1 or 0)

    sub:add(pf.h_counter, tvb(4, 4), h.counter)

    if h.src_off then
        local it = sub:add(pf.h_src, tvb(h.src_off, 8), tvb(h.src_off, 8):le_uint64())
        if h.unsecured then
            it:append_text("  [random ephemeral ID during handshake - anti-correlation]")
        end
    end
    if h.dst_off then
        sub:add(pf.h_dst, tvb(h.dst_off, 8), tvb(h.dst_off, 8):le_uint64())
    end
    if h.grp_off then
        sub:add(pf.h_dstgrp, tvb(h.grp_off, 2), tvb(h.grp_off, 2):le_uint())
    end

    sub:add(pf.h_len, h.hdr_len):set_generated()
    return sub
end

local function render_exchange_header(tvb, e, tree)
    local sub = tree:add(matterx, tvb(e.off, e.hdr_len))
    local opname = SC_OPCODE[e.opcode]
    local pname  = PROTOCOL_ID[e.protocol_id] or
                   string.format("0x%04X", e.protocol_id)
    if e.protocol_id ~= 0x0000 then opname = nil end
    sub:set_text(string.format("Exchange Header - %s%s", pname,
        opname and (": " .. opname) or ""))

    local f = sub:add(pf.x_flags, tvb(e.off, 1), e.flags)
    f:add(pf.x_initiator,  tvb(e.off,1), e.initiator and 1 or 0)
    f:add(pf.x_ack,        tvb(e.off,1), e.ack and 1 or 0)
    f:add(pf.x_reliable,   tvb(e.off,1), e.reliability and 1 or 0)
    f:add(pf.x_secext,     tvb(e.off,1), e.sec_ext and 1 or 0)
    f:add(pf.x_vendor,     tvb(e.off,1), e.vendor and 1 or 0)

    local op = sub:add(pf.x_opcode, tvb(e.off + 1, 1), e.opcode)
    if opname then
        op:append_text("  (" .. opname .. ")")
        sub:add(pf.x_opname, opname):set_generated()
    end

    sub:add(pf.x_id, tvb(e.off + 2, 2), e.exchange_id)
    if e.vendor_off then
        sub:add(pf.x_vendorid, tvb(e.vendor_off, 2), tvb(e.vendor_off, 2):le_uint())
    end
    sub:add(pf.x_protocol, tvb(e.proto_off, 2), e.protocol_id)
    if e.ack_off then
        sub:add(pf.x_ackctr, tvb(e.ack_off, 4), tvb(e.ack_off, 4):le_uint())
           :append_text("  [MRP piggybacked acknowledgement]")
    end
    return sub
end

function matterx.dissector(tvb, pinfo, tree)
    state.counts.udp5540 = state.counts.udp5540 + 1

    -- Let Wireshark's own Matter dissector build its tree too, if present.
    if matterx.prefs.callbuiltin and builtin_matter then
        pcall(function() builtin_matter:call(tvb, pinfo, tree) end)
    else
        pinfo.cols.protocol:set("Matter")
    end

    local root = tree:add(matterx, tvb())
    root:set_text("Matter Analysis")

    local h, herr = parse_message_header(tvb)
    if not h then
        state.counts.badhdr = state.counts.badhdr + 1
        root:add(pf.status, "not a parseable Matter message: " .. tostring(herr))
        root:add_proto_expert_info(ei.malformed, tostring(herr))
        return tvb:len()
    end

    state.counts.parsed = state.counts.parsed + 1
    render_message_header(tvb, h, root)

    local conv  = get_conv(pinfo)
    local label = nil

    if h.unsecured then
        state.counts.unsecured = state.counts.unsecured + 1
        root:append_text("  [unsecured session - handshake in the clear]")

        local e, eerr = parse_exchange_header(tvb, h.hdr_len)
        if not e then
            root:add(pf.status, "exchange header unparseable: " .. tostring(eerr))
            root:add_proto_expert_info(ei.malformed, tostring(eerr))
            return tvb:len()
        end
        render_exchange_header(tvb, e, root)

        if e.protocol_id == 0x0000 then
            label = SC_OPCODE[e.opcode]
                    or string.format("Secure Channel opcode 0x%02X", e.opcode)
            root:add(pf.message, label):set_generated()

            if e.opcode == 0x10 then
                root:add(pf.ack_only, 1):set_generated()
                root:append_text("  [standalone MRP ACK]")
            elseif e.payload_off < tvb:len() then
                local payload = tvb(e.payload_off, tvb:len() - e.payload_off):tvb()
                pcall(dissect_sc_payload, pinfo, root, e.opcode, payload(), conv)
            end
        else
            label = (PROTOCOL_ID[e.protocol_id] or "protocol")
                    .. string.format(" opcode 0x%02X", e.opcode)
            root:add(pf.message, label):set_generated()
        end
    else
        state.counts.secured = state.counts.secured + 1
        root:append_text("  [secured session - payload encrypted]")
        local ok, res = pcall(analyse_encrypted, pinfo, root, h, tvb, conv)
        if ok then label = res end
    end

    if label then pinfo.cols.info:append("  [" .. label .. "]") end
    return tvb:len()
end

--------------------------------------------------------------------------------
-- 12.  DNS-SD analysis (postdissector over the built-in mDNS dissector)
--------------------------------------------------------------------------------

local Fd = {
    txt   = safe_field("dns.txt"),
    rname = safe_field("dns.resp.name"),
    qname = safe_field("dns.qry.name"),
    ptr   = safe_field("dns.ptr.domain_name"),
    ttl   = safe_field("dns.resp.ttl"),
}

local function decode_pairing_hint(tree, range, value)
    local item, actions = tree:add(pf.sd_ph, range, value), {}
    for bit = 0, 15 do
        if band_bit(value, bit) then
            local name = PAIRING_HINT_BITS[bit] or ("reserved bit " .. bit)
            actions[#actions + 1] = name
            tree:add(pf.sd_ph_bit, range, name):set_generated()
        end
    end
    if #actions > 0 then item:append_text(" (" .. table.concat(actions, " + ") .. ")") end
    return actions
end

local function decode_tcp_flags(tree, range, value)
    local item, caps = tree:add(pf.sd_tcp, range, value), {}
    -- SDK TxtFields.cpp: kTCPClient = 1, kTCPServer = 2 are BIT POSITIONS.
    if band_bit(value, 1) then caps[#caps + 1] = "TCP client supported" end
    if band_bit(value, 2) then caps[#caps + 1] = "TCP server supported" end
    local desc = (#caps > 0) and table.concat(caps, ", ")
                             or "no TCP capability advertised"
    item:append_text(" (" .. desc .. ")")
    tree:add(pf.sd_tcp_txt, range, desc):set_generated()
end

local function handle_txt(tree, pinfo, fi)
    -- TXT values are untrusted strings: only accept integers that fit the
    -- (<= 32-bit) target fields, so TreeItem:add() never sees a bad value.
    local tonumber = function(x) return as_u32(_G.tonumber(x)) end
    local s = tostring(fi.value or "")
    local key, val = s:match("^([^=]+)=(.*)$")
    if not key then return end
    local range = fi.range

    if key == "VP" then
        local v, p = val:match("^(%d+)%+(%d+)$")
        if not v then v = val:match("^(%d+)$") end
        local vid = tonumber(v)
        if vid then
            local it = tree:add(pf.sd_vid, range, vid)
            if vid >= 0xFFF1 and vid <= 0xFFF4 then
                it:append_text(string.format(" (CSA Test Vendor %d)", vid - 0xFFF0))
                it:add_proto_expert_info(ei.test_vendor, string.format(
                    "Vendor ID 0x%04X is a CSA test VID reserved for development; "
                 .. "production devices must use an allocated VID", vid))
            end
            state.device.vendor_id = vid
        end
        local pid = tonumber(p)
        if pid then tree:add(pf.sd_pid, range, pid); state.device.product_id = pid end

    elseif key == "DT" then
        local dt = tonumber(val)
        if dt then
            local it, nm = tree:add(pf.sd_dt, range, dt), DEVICE_TYPE[dt]
            if nm then
                it:append_text(" (" .. nm .. ")")
                tree:add(pf.sd_dt_name, range, nm):set_generated()
            end
            state.device.device_type = dt
            state.device.device_type_name = nm
        end

    elseif key == "DN" then
        tree:add(pf.sd_dn, range, val)
            :append_text("  [not authenticated at discovery time]")
        state.device.name = val

    elseif key == "D" then
        local d = tonumber(val)
        if d then
            tree:add(pf.sd_disc, range, d)
                :append_text(string.format("  (short discriminator = %d)", rshift(d, 8)))
            state.device.discriminator = d
        end

    elseif key == "CM" then
        local cm = tonumber(val)
        if cm then
            local it = tree:add(pf.sd_cm, range, cm)
            if cm == 0 then
                it:add_proto_expert_info(ei.window_closed,
                    "CM=0: the device is not accepting commissioning")
                if state.device.cm ~= nil and state.device.cm ~= 0 then
                    add_event(pinfo, "DISCOVERY",
                        "Commissioning window CLOSED (CM "
                        .. tostring(state.device.cm) .. " -> 0)",
                        "Device stops accepting new commissioners")
                end
            else
                it:add_proto_expert_info(ei.window_open,
                    "CM=" .. cm .. ": the device is pairable")
            end
            state.device.cm = cm
        end

    elseif key == "PH" then
        local ph = tonumber(val)
        if ph then
            local actions = decode_pairing_hint(tree, range, ph)
            if state.device.ph ~= nil and state.device.ph ~= ph then
                add_event(pinfo, "DISCOVERY",
                    string.format("Pairing hint changed: %d -> %d", state.device.ph, ph),
                    "Now: " .. table.concat(actions, " + "))
            end
            state.device.ph = ph
            state.device.ph_actions = actions
        end

    elseif key == "PI" then tree:add(pf.sd_pi, range, val)
    elseif key == "T"  then local t = tonumber(val)
                            if t then decode_tcp_flags(tree, range, t) end
    elseif key == "SII" then local v = tonumber(val)
                             if v then tree:add(pf.sd_sii, range, v) end
    elseif key == "SAI" then local v = tonumber(val)
                             if v then tree:add(pf.sd_sai, range, v) end
    elseif key == "SAT" then local v = tonumber(val)
                             if v then tree:add(pf.sd_sat, range, v) end
    elseif key == "ICD" then
        local v = tonumber(val)
        if v then
            tree:add(pf.sd_icd, range, v):append_text(
                v == 1 and " (Long Idle Time / LIT)" or " (Short Idle Time / SIT)")
        end
    end
end

local function handle_name(tree, name)
    if type(name) ~= "string" then return end

    local cf, nid = name:match(
        "^(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)%-(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)%._matter%._tcp")
    if cf then
        local sub = tree:add(pf.sd_service, "Operational node (_matter._tcp)")
        sub:set_generated()
        local u = uint64_from_hex16(cf)
        if u then sub:add(pf.sd_cfid, u):set_generated() end
        local n = uint64_from_hex16(nid)
        if n then
            sub:add(pf.sd_node, n):set_generated()
               :append_text(string.format("  (decimal %s)", tostring(n)))
        end
        state.fabric.compressed, state.fabric.node = cf, nid
        return
    end

    if name:match("^%x+%._matterc%._udp") then
        tree:add(pf.sd_service, "Commissionable node (_matterc._udp)"):set_generated()
        return
    end

    local st = name:match("^_([%w]+)%._sub%._matterc%._udp")
    if st then
        local meaning
        local v, t = st:match("^V(%d+)$"), st:match("^T(%d+)$")
        local s, l = st:match("^S(%d+)$"), st:match("^L(%d+)$")
        if v then meaning = "vendor ID " .. v
        elseif t then
            local nm = DEVICE_TYPE[tonumber(t)]
            meaning = "device type " .. t .. (nm and (" (" .. nm .. ")") or "")
        elseif s then meaning = "short discriminator " .. s
        elseif l then meaning = "long discriminator " .. l
        elseif st == "CM" then meaning = "currently in commissioning mode"
        else meaning = "unrecognised subtype" end
        tree:add(pf.sd_subtype, "_" .. st .. " -> browse by " .. meaning):set_generated()
        return
    end

    local ifab = name:match("^_I(%x+)%._sub%._matter%._tcp")
    if ifab then
        tree:add(pf.sd_subtype, "_I" .. ifab
            .. " -> browse all operational nodes on compressed fabric "
            .. ifab):set_generated()
    end
end

function matterxsd.dissector(tvb, pinfo, tree)
    if not matterx.prefs.dnssd then return end
    if pinfo.src_port ~= 5353 and pinfo.dst_port ~= 5353 then return end
    state.counts.udp5353 = state.counts.udp5353 + 1

    local names = {}
    local sources = { all(Fd.qname), all(Fd.rname), all(Fd.ptr) }
    for _, list in ipairs(sources) do
        for _, fi in ipairs(list) do
            local v = tostring(fi.value or "")
            if v ~= "" then names[v] = true end
        end
    end

    local is_matter = false
    for n in pairs(names) do
        if n:find("_matterc%._udp") or n:find("_matter%._tcp") then
            is_matter = true; break
        end
    end
    if not is_matter then return end
    state.counts.dnssd = state.counts.dnssd + 1

    local st = tree:add(matterxsd)
    st:set_text("Matter Analysis - DNS-SD service discovery")

    local nsub = st:add(matterxsd)
    nsub:set_text("Service names and subtypes")
    local sorted = {}
    for n in pairs(names) do sorted[#sorted + 1] = n end
    table.sort(sorted)
    for _, n in ipairs(sorted) do pcall(handle_name, nsub, n) end

    local txts = all(Fd.txt)
    if #txts > 0 then
        local tsub = st:add(matterxsd)
        tsub:set_text("TXT record keys (decoded)")
        for _, fi in ipairs(txts) do
            if not pcall(handle_txt, tsub, pinfo, fi) then
                tsub:add_proto_expert_info(ei.malformed, "Unparseable TXT string")
            end
        end
    end

    local goodbye = false
    for _, fi in ipairs(all(Fd.ttl)) do
        if tonum(fi.value) == 0 then goodbye = true; break end
    end
    if goodbye then
        local it = st:add(pf.sd_goodbye, 1)
        it:set_generated()
        it:add_proto_expert_info(ei.goodbye,
            "TTL=0 instructs all caches on the link to discard these records now")
        add_event(pinfo, "DISCOVERY", "mDNS goodbye (TTL=0)",
            "Explicit cache invalidation - marks a device state transition")
    end
end

--------------------------------------------------------------------------------
-- 13.  Registration
--
-- Claiming udp.port explicitly is what makes this work: a port-registered
-- dissector runs ahead of heuristic dissectors, so the WireGuard heuristic can
-- no longer steal Matter frames.
--------------------------------------------------------------------------------

local reg = { port = nil, replaced = false, error = nil }

do
    local port = matterx.prefs.port
    if port == nil or port == 0 then port = 5540 end
    local ok, err = pcall(function()
        local t = DissectorTable.get("udp.port")
        local prev = t:get_dissector(port)
        if prev then reg.replaced = true end
        t:add(port, matterx)
    end)
    reg.port = port
    if not ok then reg.error = tostring(err) end
end

register_postdissector(matterxsd)

--------------------------------------------------------------------------------
-- 14.  Reports
--------------------------------------------------------------------------------

local function build_diagnostics()
    local L = {}
    local function w(f, ...)
        if select("#", ...) > 0 then L[#L+1] = string.format(f, ...) else L[#L+1] = f end
    end

    w("================ MATTER ANALYSIS DIAGNOSTICS ================")
    w("")
    w("-- SCRIPT REGISTRATION ---------------------------------------")
    w("  Lua version                : %s", _VERSION or "unknown")
    w("  Registered on UDP port     : %s", tostring(reg.port))
    w("  Replaced an existing entry : %s", reg.replaced and "yes" or "no")
    if reg.error then
        w("  REGISTRATION ERROR         : %s", reg.error)
        w("  -> the dissector is NOT attached; nothing will be decoded.")
    end
    w("  Built-in 'matter' dissector: %s",
      builtin_matter and "found (also invoked)" or "NOT FOUND (not required)")
    w("")
    w("  This script parses the Matter header itself, so a missing built-in")
    w("  dissector is harmless. Only a REGISTRATION ERROR above is fatal.")
    w("")

    w("-- mDNS FIELD AVAILABILITY -----------------------------------")
    local names = {"txt","rname","qname","ptr","ttl"}
    for _, k in ipairs(names) do
        w("  dns.%-8s : %s", k, Fd[k] and "available" or "MISSING")
    end
    w("")

    w("-- PACKET COUNTS (this dissection pass) ----------------------")
    local c = state.counts
    w("  UDP packets on port %-5s : %d", tostring(reg.port), c.udp5540)
    w("    header parsed OK         : %d", c.parsed)
    w("    unsecured (handshake)    : %d", c.unsecured)
    w("    secured (encrypted)      : %d", c.secured)
    w("    header unparseable       : %d", c.badhdr)
    w("  UDP packets on port 5353   : %d", c.udp5353)
    w("    Matter DNS-SD records    : %d", c.dnssd)
    w("  Timeline events recorded   : %d", (function()
        local n = 0; for _ in pairs(state.events) do n = n + 1 end; return n end)())
    w("")

    w("-- INTERPRETATION --------------------------------------------")
    if c.udp5540 == 0 and c.udp5353 == 0 then
        w("  No traffic reached this script at all.")
        w("")
        w("  * Is a capture file actually open?")
        w("  * Is your Matter traffic on a port other than %s?", tostring(reg.port))
        w("    Set the correct port in Preferences > Protocols > MATTERX,")
        w("    then RESTART Wireshark (port registration happens at load).")
        w("  * Check Preferences > Protocols > UDP and make sure")
        w("    'Try heuristic sub-dissectors first' is DISABLED.")
    elseif c.udp5540 > 0 and c.parsed == 0 then
        w("  Packets arrived but none parsed as Matter. The traffic on this")
        w("  port is probably not Matter, or is truncated.")
    elseif c.parsed > 0 then
        w("  Working normally. Expand 'Matter Analysis' in the packet detail")
        w("  pane, or open Tools > Matter > Capture Analysis Report.")
        if c.unsecured == 0 then
            w("")
            w("  NOTE: no unsecured handshake frames were seen, so session types")
            w("  cannot be classified and inference will be limited. This happens")
            w("  when a capture starts after commissioning.")
        end
    end
    w("")
    w("=============================================================")
    return table.concat(L, "\n")
end

local function build_report()
    local L = {}
    local function w(f, ...)
        if select("#", ...) > 0 then L[#L+1] = string.format(f, ...) else L[#L+1] = f end
    end

    w("================================================================")
    w("  MATTER CAPTURE ANALYSIS REPORT")
    w("================================================================")
    w("")

    w("-- DEVICE (from DNS-SD advertisements) -------------------------")
    local d = state.device
    if next(d) == nil then
        w("  No Matter DNS-SD advertisements were seen in this capture.")
    else
        w("  Name              : %s", d.name or "(not advertised)")
        if d.vendor_id then
            local extra = ""
            if d.vendor_id >= 0xFFF1 and d.vendor_id <= 0xFFF4 then
                extra = string.format("  <-- CSA Test Vendor %d, development only",
                                      d.vendor_id - 0xFFF0)
            end
            w("  Vendor ID         : 0x%04X%s", d.vendor_id, extra)
        end
        if d.product_id then w("  Product ID        : 0x%04X", d.product_id) end
        if d.device_type then
            w("  Device type       : 0x%04X  %s", d.device_type,
              d.device_type_name or "(unknown type)")
        end
        if d.discriminator then
            w("  Discriminator     : %d (long), %d (short)",
              d.discriminator, rshift(d.discriminator, 8))
        end
        if d.cm then w("  Commissioning mode: %s", CM_MODE[d.cm] or tostring(d.cm)) end
        if d.ph_actions and #d.ph_actions > 0 then
            w("  Pairing hint      : %d -> %s", d.ph or 0,
              table.concat(d.ph_actions, " + "))
        end
    end
    w("")

    w("-- FABRIC / OPERATIONAL IDENTITY -------------------------------")
    if state.fabric.compressed then
        w("  Compressed fabric ID : 0x%s", state.fabric.compressed)
        w("  Operational node ID  : 0x%s", state.fabric.node or "?")
        local n = state.fabric.node and tonumber(state.fabric.node, 16)
        if n then w("                         (decimal %d)", n) end
        w("")
        w("  The real Fabric ID, Root CA public key, IPK and every certificate")
        w("  stay encrypted (inside AddNOC and the CASE Sigma payloads). The")
        w("  compressed fabric ID is a one-way KDF output, so the capture does")
        w("  not disclose the fabric's cryptographic identity.")
    else
        w("  No operational (_matter._tcp) advertisement observed.")
    end
    w("")

    w("-- PARTICIPANTS ------------------------------------------------")
    local any = false
    for _, c in pairs(state.convs) do
        if c.commissioner or c.device then
            any = true
            w("  Commissioner / Controller : %s", c.commissioner or "(unresolved)")
            w("  Commissionee / Node       : %s", c.device or "(unresolved)")
            w("  CASE sessions established : %d", c.case_count)
            w("  Commissioning completed   : %s",
              c.commissioning_complete and "yes" or "not observed")
        end
    end
    if not any then w("  No Matter Secure Channel handshake was observed.") end
    w("")

    if next(state.specs) then
        w("-- REPORTED SPECIFICATION VERSIONS ----------------------------")
        local vs, n = {}, 0
        for addr, rec in pairs(state.specs) do
            w("  %-28s %s (frame %d)", addr, spec_version_str(rec.version), rec.frame)
            vs[rec.version] = true
        end
        for _ in pairs(vs) do n = n + 1 end
        if n > 1 then
            w("")
            w("  NOTE: the peers report different specification versions, so this")
            w("  capture exercises Matter's forward/backward compatibility rules.")
        end
        w("")
    end

    w("-- SESSIONS ----------------------------------------------------")
    local sids = {}
    for sid in pairs(state.sessions) do sids[#sids + 1] = sid end
    table.sort(sids)
    if #sids == 0 then
        w("  No secure session IDs were negotiated in the clear.")
    else
        w("  %-10s %-6s %s", "SessionID", "Kind", "First seen (frame)")
        for _, sid in ipairs(sids) do
            local s = state.sessions[sid]
            w("  0x%04X     %-6s %d", sid, s.kind, s.first_frame)
        end
        w("")
        w("  Reminder: a session ID is allocated by the RECEIVER, so each logical")
        w("  session appears above under two different IDs, one per direction.")
    end
    w("")

    w("-- TIMELINE ----------------------------------------------------")
    local frames = {}
    for fn in pairs(state.events) do frames[#frames + 1] = fn end
    table.sort(frames)
    if #frames == 0 then
        w("  No Matter events recorded.")
        w("  Open Tools > Matter > Diagnostics to find out why.")
    else
        w("  %-7s %-10s %-14s %s", "Frame", "t (s)", "Phase", "Event")
        w("  " .. string.rep("-", 92))
        local prev
        for _, fn in ipairs(frames) do
            local e = state.events[fn]
            if prev and prev ~= e.phase then w("") end
            w("  %-7d %-10.6f %-14s %s", e.frame, e.ts, e.phase, e.label)
            if e.detail and e.detail ~= "" then
                w("  %-7s %-10s %-14s    %s", "", "", "", e.detail)
            end
            prev = e.phase
        end
    end
    w("")

    if state.commissioned_ts and state.first_ts then
        w("-- PHASE SUMMARY ----------------------------------------------")
        w("  First observed packet      t = %.6f s", state.first_ts)
        w("  Commissioning complete     t = %.6f s (frame %d)",
          state.commissioned_ts, state.commissioned_frame or 0)
        w("  Total commissioning time   %.3f ms",
          (state.commissioned_ts - state.first_ts) * 1000)
        if state.last_ts then
            w("  Last observed event        t = %.6f s", state.last_ts)
        end
        w("")
    end

    w("-- WHAT THIS CAPTURE CANNOT TELL YOU ---------------------------")
    w("  Only the Secure Channel handshakes travel in the clear. Everything")
    w("  carried inside a PASE or CASE session is AES-128-CCM encrypted, so:")
    w("")
    w("    * cluster IDs, attribute IDs, command IDs and all TLV values are")
    w("      NOT observable;")
    w("    * every 'inferred' item in the packet detail is a guess derived from")
    w("      direction, plaintext length and sequence position;")
    w("    * a no-argument command (On, Off, Toggle, CommissioningComplete) is")
    w("      indistinguishable from any other no-argument command by size.")
    w("")
    w("  What IS observable: both endpoints, timing, message sizes, session")
    w("  lifecycle, MRP behaviour, and the full DNS-SD metadata.")
    w("")
    w("  For ground truth, re-run the controller with SDK tracing enabled")
    w("  (chip-tool --trace_decode 1) and compare against the inference here.")
    w("")
    w("================================================================")
    return table.concat(L, "\n")
end

if gui_enabled() then
    local function window(title, builder)
        local win = TextWindow.new(title)
        win:set("Collecting data, please wait...\n")
        local ok, err = pcall(retap_packets)
        if not ok then
            win:set("Could not retap packets: " .. tostring(err)
                    .. "\n\nOpen a capture file first, then reopen this window.\n")
            return
        end
        win:set(builder())
        win:add_button("Copy to clipboard", function() copy_to_clipboard(builder()) end)
    end

    register_menu("Matter/Capture Analysis Report",
        function() window("Matter Capture Analysis", build_report) end,
        MENU_TOOLS_UNSORTED)

    register_menu("Matter/Diagnostics",
        function() window("Matter Analysis Diagnostics", build_diagnostics) end,
        MENU_TOOLS_UNSORTED)
end

if not gui_enabled() then
    local tap = Listener.new("frame")
    function tap.packet() end
    function tap.reset()  end
    function tap.draw()
        if matterx.prefs.stdout_report then
            print(build_report())
            print("")
            print(build_diagnostics())
        end
    end
end