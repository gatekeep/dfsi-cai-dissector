-- Lua Dissector for DFSI CAI based on Thomas Edwards dissector for ST 2110_20
-- Author: Vitor Espindola (vitor.espindola@byne.com.br)
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
--
------------------------------------------------------------------------------------------------
do
    local dfsi_cai = Proto("dfsi_cai", "DFSI CAI")

    local F = dfsi_cai.fields
    -- CAI Frame
    F.Signal = ProtoField.uint8("dfsi.cai.signalbit","Signal Bit",base.DEC,nil)
    F.Compact = ProtoField.uint8("dfsi.cai.compact","Compact",base.DEC,nil)
    F.BlockHeaderCount = ProtoField.uint8("dfsi.cai.count","Block Header Count",base.DEC,nil)
    F.P25 = ProtoField.bool("dfsi.cai.p25","P25 specific payload",8,{"Yes","No"},0x80)
    F.BlockPayloadType = ProtoField.uint8("dfsi.cai.payload_type","Block Payload Type",base.DEC,nil)
    -- F.Data = ProtoField.bytes("dfsi.cai.data","Data")

    -- P25 CAI
    F.P25FrameType = ProtoField.uint8("dfsi.cai.p25.frametype","CAI Voice Frame Type",base.HEX,nil)
    F.P25Voice = ProtoField.bytes("dfsi.cai.p25.voice","IMBE Voice Payload")
    F.P25ReportErrorTotal = ProtoField.uint8("dfsi.cai.p25.report.error_total","Report Error Total",base.DEC,nil)
    F.P25ReportErrorScaled = ProtoField.uint8("dfsi.cai.p25.report.error_scaled","Report Error Total",base.DEC,nil)
    F.P25ReportMute = ProtoField.bool("dfsi.cai.p25.report.mute","Report Mute")
    F.P25ReportLost = ProtoField.bool("dfsi.cai.p25.report.lost","Report Lost")
    F.P25ReportErrorE4 = ProtoField.uint8("dfsi.cai.p25.report.error_total","Report Error E4",base.DEC)
    F.P25ReportErrorE1 = ProtoField.uint8("dfsi.cai.p25.report.error_total","Report Error E1",base.DEC)
    F.P25SuperFrame = ProtoField.uint8("dfsi.cai.p25.superframe","Super frame",base.DEC)
    F.P25Busy = ProtoField.uint8("dfsi.cai.p25.busy","Busy",base.DEC)

    function dfsi_cai.dissector(tvb, pinfo, tree)
        local subtree = tree:add(dfsi_cai, tvb(), "DFSI CAI")
        subtree:add(F.Signal, tvb(0,1):bitfield(0,1))

        local compact = tvb(0,1):bitfield(1,1)
        subtree:add(F.Compact, compact, nil, label(labels_compact, compact))

        subtree:add(F.BlockHeaderCount, tvb(0,1):bitfield(2,6))

        subtree:add(F.P25, tvb(1,1))

        local p25 = tvb(1,1):bitfield(0,1)
        if p25 == 1 then
            block_pt_type = tvb(1,1):bitfield(1,7)
            subtree:add(F.BlockPayloadType, block_pt_type, nil, label(labels_block_pt, block_pt_type))

            if block_pt_type == 0 then
                dissect_cai_voice(tvb, pinfo, subtree)
            end
        end
        -- subtree:add(F.Data,tvb(0,tvb:len()))
    end

    function dissect_cai_voice(tvb, pinfo, tree)
        local cai_frame_type = tvb(2,1):uint()
        local subtree = tree:add(dfsi_cai, tvb(), labels_cai_frame_type[cai_frame_type])

        subtree:add(F.P25FrameType, cai_frame_type, nil, label(labels_cai_frame_type, cai_frame_type))
        subtree:add(F.P25SuperFrame, tvb(15,1):bitfield(4,2))

        subtree:add(F.P25Voice,tvb(3,11))

        local cai_frame_status = tvb(15,1):bitfield(6,2)
        subtree:add(F.P25Busy, cai_frame_status, nil, label(labels_cai_frame_status, cai_frame_status))

        subtree:add(F.P25ReportErrorTotal, tvb(14,1):bitfield(0,3))
        subtree:add(F.P25ReportErrorScaled, tvb(14,1):bitfield(3,3))
        subtree:add(F.P25ReportMute, tvb(14,1):bitfield(6,1))
        subtree:add(F.P25ReportLost, tvb(14,1):bitfield(7,1))
        subtree:add(F.P25ReportErrorE4, tvb(15,1):bitfield(0,1))
        subtree:add(F.P25ReportErrorE1, tvb(15,1):bitfield(1,3))
    end

    -- register dissector to dynamic payload type dissectorTable
    local dyn_payload_type_table = DissectorTable.get("rtp_dyn_payload_type")
    dyn_payload_type_table:add("dfsi_cai", dfsi_cai)

    -- register dissector to RTP payload type
    local payload_type_table = DissectorTable.get("rtp.pt")
    function dfsi_cai.init()
        payload_type_table:add(100, dfsi_cai)
    end
end


function label(labels, value, default)
    if default == nil then
        default = "Unknown"
    end

    local l = labels[value]
    if l == nil then
        l = default
    end

    return "(".. l ..")"
end

labels_compact = {}
labels_compact[0] = "Reserved"
labels_compact[1] = "Compact"

labels_block_pt = {}
labels_block_pt[0] = "CAI Voice"
labels_block_pt[6] = "Voice Header Part 1"
labels_block_pt[7] = "Voice Header Part 2"
labels_block_pt[9] = "Start of Stream"
labels_block_pt[10] = "End of Stream"
labels_block_pt[12] = "Voter Report"
labels_block_pt[13] = "Voter Control"
labels_block_pt[14] = "TX Key Acknowledge"
-- TODO
-- 63-127 – Manufacturer Specific

labels_cai_frame_type = {}
labels_cai_frame_type[98] = "IMBE Voice 1"
labels_cai_frame_type[99] = "IMBE Voice 2"
labels_cai_frame_type[100] = "IMBE Voice 3 + Link Control"
labels_cai_frame_type[101] = "IMBE Voice 4 + Link Control"
labels_cai_frame_type[102] = "IMBE Voice 5 + Link Control"
labels_cai_frame_type[103] = "IMBE Voice 6 + Link Control"
labels_cai_frame_type[104] = "IMBE Voice 7 + Link Control"
labels_cai_frame_type[105] = "IMBE Voice 8 + Link Control"
labels_cai_frame_type[106] = "IMBE Voice 9 + Low Speed Data"
labels_cai_frame_type[107] = "IMBE Voice 10"
labels_cai_frame_type[108] = "IMBE Voice 11"
labels_cai_frame_type[109] = "IMBE Voice 12 + Encryption Sync"
labels_cai_frame_type[110] = "IMBE Voice 13 + Encryption Sync"
labels_cai_frame_type[111] = "IMBE Voice 14 + Encryption Sync"
labels_cai_frame_type[112] = "IMBE Voice 15 + Encryption Sync"
labels_cai_frame_type[113] = "IMBE Voice 16 + Encryption Sync"
labels_cai_frame_type[114] = "IMBE Voice 17 + Encryption Sync"
labels_cai_frame_type[115] = "IMBE Voice 18 + Low Speed Data"

labels_cai_frame_status = {}
labels_cai_frame_status[1] = "Inbound Channel is Busy"
labels_cai_frame_status[0] = "Unknown, use for talk-around"
labels_cai_frame_status[2] = "Unknown, use for inbound or outbound"
labels_cai_frame_status[3] = "Inbound Channel is Idle"

