DataView = {}
DataView.__index = DataView

local function NewArrayBuffer(size)
    local self = setmetatable({}, DataView)
    self.buffer = string.rep("\0", size)
    return self
end

function DataView.ArrayBuffer(size)
    return NewArrayBuffer(size)
end

function DataView:Buffer()
    return self.buffer
end

function DataView:SetInt32(offset, value)
    local stringValue = string.pack("<i4", value)
    self.buffer = self.buffer:sub(1, offset) .. stringValue .. self.buffer:sub(offset + 5)
end

function DataView:GetInt32(offset)
    return string.unpack("<i4", self.buffer, offset + 1)
end

function DataView:SetUint32(offset, value)
    local stringValue = string.pack("<I4", value)
    self.buffer = self.buffer:sub(1, offset) .. stringValue .. self.buffer:sub(offset + 5)
end

function DataView:GetUint32(offset)
    return string.unpack("<I4", self.buffer, offset + 1)
end

function DataView:SetInt64(offset, value)
    local stringValue = string.pack("<i8", value)
    self.buffer = self.buffer:sub(1, offset) .. stringValue .. self.buffer:sub(offset + 9)
end

function DataView:GetInt64(offset)
    return string.unpack("<i8", self.buffer, offset + 1)
end
