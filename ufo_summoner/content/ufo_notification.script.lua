local M = {
	useDataState = function(params)
		params = params or {}
		return {
			title = params.title or _("UFO Summoner"),
			description = params.description or "",
			icon = params.icon or "::/game_mechanics/notifications/gui/icons/task_complete.tga",
		}
	end,
}

function data()
	return M
end

return M
