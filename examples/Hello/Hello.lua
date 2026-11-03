local M = AddonsForever:NewModule("Hello")

function M:OnEnable()
  self:Log("Hello from Addons Forever! Logged in as", UnitName("player"))
end
