local Quest = {}
local Players = game:GetService("Players")

local updateCallback = nil
local isRunning = false

function Quest.OnUpdate(callback)
    updateCallback = callback
end

-- Função para procurar quests abertas (Template base para VV Ultimato)
local function scanQuests()
    local quests = {}
    local player = Players.LocalPlayer
    
    if player and player:FindFirstChild("PlayerGui") then
        -- Exemplo de como a estrutura da quest deve ser montada para a UI:
        -- [[
        -- table.insert(quests, {
        --     title = "Exemplo de Quest",
        --     source = "NPC Incial",
        --     location = "Spawn",
        --     steps = {
        --         { icon = "⚔️", text = "Derrotar Inimigos", prog = "0/5" }
        --     }
        -- })
        -- ]]
        
        -- TODO: Adicione aqui a lógica específica para ler a UI ou os atributos
        -- do "VV Ultimato" e preencher a tabela `quests` com as quests ativas.
    end
    
    return { found = #quests > 0, quests = quests }
end

function Quest.start()
    if isRunning then return end
    isRunning = true
    
    task.spawn(function()
        while isRunning do
            if updateCallback then
                local data = scanQuests()
                updateCallback(data)
            end
            -- Atualiza a cada 2 segundos para evitar lag na recriação dos cards da UI
            task.wait(2)
        end
    end)
end

function Quest.stop()
    isRunning = false
end

return Quest
