dots = ""
function validResponse(text, statusCode)
	return (text ~= nil and statusCode ~= nil and tonumber(statusCode) == 200)
end

Citizen.CreateThread(function()
	config = json.decode( LoadResourceFile(GetCurrentResourceName(), "config.json") )[1]
	
	PerformHttpRequest('http://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key='..config.APIKey..'&steamids=76561198081509001', function(statusCode, text, headers)
	    if statusCode == 403 then
				Citizen.Trace("\n--------------------------------")
				Citizen.Trace("\nSteam API Key Incorreta!")
				Citizen.Trace("\n--------------------------------\n")
	    end
	end, 'GET', json.encode({}), { ["Content-Type"] = 'application/json' })
	
	AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
		local numIds = GetPlayerIdentifiers(source)
		deferrals.defer()
		deferrals.update("Verificando sua Conta Steam.")
		local s = source
		local n = name
		local deferrals = deferrals
		
		local decline = false
		Wait(100)
		local steamid = GetPlayerIdentifier(s,0)
		if not steamid then 
			Wait(1000)
			deferrals.done("A Steam deve estar em execução para jogar neste servidor.")
			return 
		end
		if not string.find(steamid,"steam:") then
			Wait(1000)
			deferrals.done("A Steam deve estar em execução para jogar neste servidor.")
			return
		end
		
		if #GetPlayers() == GetConvarInt("sv_maxclients", 30) then
			deferrals.done("A Cidade está Lotada :/")
		end
		local steam64 = tonumber(string.gsub(steamid,"steam:", ""),16)
		if not steam64 then
			Wait(1000)
			deferrals.done("A Steam deve estar em execução para jogar neste servidor.")
			return
		end
		local gotBans = false -- make sure we wait for our response
		local vacBans = false
		local vacBanned = false
		
		
		repeat
			PerformHttpRequest('http://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key='..config.APIKey..'&steamids='..steam64..'', function(statusCode, text, headers)
			    if text then
						if validResponse(text, statusCode) then
							local info = json.decode(text)
															
							vacBanned = info['players'][1]['VACBanned']
							vacBans = info['players'][1]['NumberOfVACBans']

							if info['players'][1]['DaysSinceLastBan'] > config.MaxDaysSinceLastBan then
								vacBanned = false
							end
						else
							vacBanned = false
						end

					gotBans = true
			    end
			end, 'GET', json.encode({}), { ["Content-Type"] = 'application/json' })
			Wait(300)
			deferrals.update("Verificando sua Conta Steam..")
		until (gotBans)
		
		Wait(1000)
		deferrals.update("Verificando sua Conta Steam...")
		dots = "..."
		Wait(1000)
		local gotAccountAge = false -- make sure we wait for our response
		local timecreated = false
		repeat
			PerformHttpRequest('https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key='..config.APIKey..'&steamids='..steam64..'', function(statusCode, text, headers)
			    if text then
						if validResponse(text, statusCode) then
							local info = json.decode(text)
							if info['response']['players'][1]['timecreated'] then
								timecreated = info['response']['players'][1]['timecreated']
							else
								timecreated = false
							end
							profileVisibility = info['response']['players'][1]['communityvisibilitystate']
						else
							timecreated = config.MinimumAccountAge
						end
					gotAccountAge = true
			    end
			end, 'GET', json.encode({}), { ["Content-Type"] = 'application/json' })
			Wait(300)
			deferrals.update("Verificando sua Conta Steam."..dots)
		until (gotAccountAge)
			
		local playtime = false
		repeat
			PerformHttpRequest('https://api.steampowered.com/IPlayerService/GetRecentlyPlayedGames/v0001/?key='..config.APIKey..'&steamid='..steam64..'´&format=json', function(statusCode, text, headers)
				if text then
					if validResponse(text, statusCode) then
						local response = json.decode(text)
						local data = response['response']
						if data.games then
							for i,v in pairs(data.games) do
								if v.appid == 218 then
									playtime = math.ceil(v.playtime_forever / 60)
									break
								end
							end
						end
					else
						playtime = config.MinimumPlaytimeHours
					end
				end
			end, 'GET', json.encode({}), { ["Content-Type"] = 'application/json' })
			Wait(300)
			deferrals.update("Verificando sua Conta Steam."..dots)
		until (playtime)
		
		local gotOwnedGames = false
		local ownedGames = 0
		local globalplaytime = false
		repeat
			PerformHttpRequest('https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key='..config.APIKey..'&steamid='..steam64..'´&format=json', function(statusCode, text, headers)
				if text then
					if validResponse(text, statusCode) then
						local response = json.decode(text)
						local data = response['response']
						if data.games then
							globalplaytime = 0
							for i,a in pairs(data.games) do
								if a.playtime_forever then
									globalplaytime = globalplaytime+a.playtime_forever 
								end
							end
						end
						
						if not globalplaytime or globalplaytime == 0 then
							globalplaytime = 9999 -- user game data is private, this is a dirty hack to fix this issue
						end
						
						ownedGames = data.game_count
					else
						globalplaytime = 9999
						ownedGames = config.MinimumOwnedGames
					end
					gotOwnedGames = true
				end
			end, 'GET', json.encode({}), { ["Content-Type"] = 'application/json' })
			Wait(300)
			deferrals.update("Verificando sua Conta Steam."..dots)
		until (gotOwnedGames)
		
		
		deferrals.update("Verificando sua Conta Steam."..dots)
		repeat
			Wait(500)
			dots = dots.."."
			if string.len(dots) > 20 and string.len(dots) < 60 then
				deferrals.update("Levando muito tempo? Tente reconectar ou entre em contato com o proprietário do servidor!")
			elseif string.len(dots) == 60 then
				deferrals.done("Falha na verificação da conta da Steam, a solicitação da API da Steam demorou muito.")
				break
			else
				deferrals.update("Verificando sua Conta Steam"..dots)
			end
		until (gotBans and gotAccountAge and gotOwnedGames)
		dots = dots.."."
		deferrals.update("Verificando sua Conta Steam"..dots)
		Wait(500)
		local strikes = 0
		string = "Você não tem permissão para entrar neste servidor, motivo (s): "
		if config.EnableVACBans and vacBanned and vacBans >= config.MaxVACCount then
			string = string.."[1] Mais de ".. config.MaxVACCount-1 .." VAC Ban(s) na Conta "
			decline = true
			strikes = strikes+1
		end
		if config.EnableAccountAgeCheck and timecreated and (os.time() - timecreated) < config.MinimumAccountAge then
			string = string.."[2] A conta é nova, menor que "..config.MinimumAccountAgeLabel.." "
			decline = true
			strikes = strikes+1
		end
		if config.EnableMinimumPlaytime and playtime and playtime < config.MinimumPlaytimeHours then
			string = string.."[3] Menos de "..config.MinimumPlaytimeHours.." Horas jogadas no FiveM ("..config.MinimumPlaytimeHours-playtime.." Horas Restante)"
			decline = true
			strikes = strikes+1
		end 
		if config.EnableMinimumOwnedGames and ownedGames and ownedGames < config.MinimumOwnedGames then
			string = string.."[4] Menos de "..config.MinimumOwnedGames.." Jogos comprados na Steam ("..config.MinimumOwnedGames-ownedGames.." Jogos Faltando)"
			decline = true
			strikes = strikes+1
		end
		if globalplaytime and config.MinimumTotalPlaytimeHours > globalplaytime then
			string = string.."[5] Menos de "..config.MinimumTotalPlaytimeHours.." Horas jogadas na Steam ("..config.MinimumTotalPlaytimeHours-globalplaytime.." Horas Restante)"
			decline = true
			strikes = strikes+1
		end
		if profileVisibility == 1 and (not globalplaytime or not playtime or not timecreated) then
			string = string.."[6] Falha na verificação da sua conta da Steam, defina seu perfil da Steam como 'Público' e volte ao servidor."
			decline = true
			strikes = strikes+1
		end

		
		if decline and strikes >= config.MaxStrikes then
			deferrals.done(string)
		else
			deferrals.done()
		end
	end)
end)
