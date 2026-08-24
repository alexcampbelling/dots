-- hosts.lua — "which computer am I?"
-- Reads /etc/hostname and returns it as a string (e.g. "laparch", "pcarch").
-- require("conf/hosts") gives you that string directly.
--
-- Why not os.getenv("HOSTNAME")? SDDM doesn't export HOSTNAME into Hyprland's
-- environment, so it's nil here. /etc/hostname is always present on Arch.

local f    = io.open("/etc/hostname", "r")
local name = f and (f:read("*l") or "") or ""
if f then f:close() end

return name:gsub("%s+$", "")
