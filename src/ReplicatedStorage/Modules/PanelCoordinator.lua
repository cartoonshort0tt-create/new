-- Shared panel visibility coordinator. ShopUI/UpgradeUI/CrateUI each used to
-- flip their own panel's Visible property independently, so opening one
-- never closed another -- multiple panels could stack on screen with no
-- way to get them to "go back". Every toggling panel registers itself here
-- and calls PanelCoordinator.toggle(name) instead of touching Visible
-- directly, so opening one always closes the others.

local PanelCoordinator = {}

local panels = {} -- name -> Frame

function PanelCoordinator.register(name, frame)
	panels[name] = frame
end

function PanelCoordinator.hideAll()
	for _, frame in pairs(panels) do
		frame.Visible = false
	end
end

function PanelCoordinator.showOnly(name)
	for panelName, frame in pairs(panels) do
		frame.Visible = (panelName == name)
	end
end

function PanelCoordinator.toggle(name)
	local frame = panels[name]
	if not frame then
		return
	end
	if frame.Visible then
		frame.Visible = false
	else
		PanelCoordinator.showOnly(name)
	end
end

return PanelCoordinator
