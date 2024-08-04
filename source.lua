local consio = {}

consio.Debug = true
consio.Client = {}
consio.Server = {}

-- Services
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ModelPhysics = require(script.ModelPhysics)
local Vyn

-- Types
type Action = any

type Block = {
	Name: string,
	instance: Instance,
	Parent: Block?,
	Attributes: { [string]: any },
	Actions: { [Enum.KeyCode]: Action }
}

-- Helper functions
local function Debug(message: any)
	if consio.Debug then
		print(`[CONSIO] | [DEBUG]: {tostring(message)}`)
	end
end

local function GetOrCreateFolder(folderName: string, parent: Instance)
	local folder = parent:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
		Debug(`Created folder: {folderName}`)
	end
	return folder
end

-- Vyn Setup
if ReplicatedStorage:FindFirstChild("Vyn") then
	Debug("Found Vyn!")
	Vyn = require(ReplicatedStorage.Vyn)
else
	Debug("Vyn is not installed, installing..")
	Vyn = script.Vyn
	Vyn.Parent = ReplicatedStorage
	Vyn = require(Vyn)
end

if RunService:IsServer() then
	if Vyn then
		Vyn:new("Consio")
	end
end

-- Consio Methods
function consio.Server.new()
	local folder = GetOrCreateFolder("ConsioBlocks", ReplicatedStorage)

	local functions = {}

	function functions:Insert(Block: Block)
		if Block.instance then
			local new = Block.instance:Clone()

			if Block.Attributes then
				for attproperty, attvalue in pairs(Block.Attributes) do
					new:SetAttribute(attproperty, attvalue)
				end
			end

			if Block.Actions then
				for key, action in pairs(Block.Actions) do
					local value = Instance.new("StringValue")
					value.Name = tostring(key)
					value.Value = tostring(key)
					value.Parent = new
				end
			end

			new.Name = Block.Name
			new.Parent = folder

			Debug(`Inserted block: {Block.instance.Name}`)

			Vyn:Listen("Consio", function(Player, name, key)
				Debug("Got request from client")
				Debug(`Got arguments {name} {key}`)

				local ganger: Instance = functions:GetBlockByName(name)

				if Block.Name == ganger.Name then
					if new:FindFirstChild(tostring(key)) then
						if Block.Actions[key] then
							Debug("Running action")
							Block.Actions[key](Player)
						end
					end
				end
			end)

		else
			Debug("Instance in block type not found, please input instance")
		end
	end

	function functions:GetAllBlocks()
		Debug("Retrieved all blocks")
		return folder:GetDescendants()
	end

	function functions:CreateIdentifiers()
		for i, block in ipairs(functions:GetAllBlocks()) do
			block:SetAttribute("Blockid", i)
		end
		Debug("Set identifiers for each block")
	end

	function functions:GetBlockById(id: number)
		for _, block in ipairs(functions:GetAllBlocks()) do
			if block:GetAttribute("Blockid") == id then
				Debug(`Retrieved block by id: {id}`)
				return block
			end
		end
	end

	function functions:GetBlockByName(name: string)
		for _, block in ipairs(functions:GetAllBlocks()) do
			if block.Name == name then
				Debug(`Retrieved block by name: {name}`)
				return block
			end
		end
	end

	function functions:BlockHasId(block: Instance, id: number)
		return block:GetAttribute("Blockid") == id
	end

	function functions:GetBlockId(block: Instance)
		return block:GetAttribute("Blockid")
	end

	function functions:HasIdentifier(block: Instance)
		return block:GetAttribute("Blockid") ~= nil
	end

	return functions, folder
end

function consio.Server:RunPhysics(model: Model, player: Player)
	local folder = ReplicatedStorage:FindFirstChild("ConsioBlocks")

	if not folder then
		Debug("ConsioBlocks folder not found in ReplicatedStorage")
		return
	end

	Vyn:Fire("Consio", player, model.Name, true)
	Debug("Sent request to client to setup keybinds")
	ModelPhysics:Launch(model)
end

function consio.Server:StopPhysics(model: Model, player: Player)
	Debug("Stopping physics")
	Vyn:Fire("Consio", player, model.Name, false)
	ModelPhysics:deLaunch(model)
end

-- Client Methods
function consio.Client.new()
	local folder = ReplicatedStorage:FindFirstChild("ConsioBlocks")

	if not folder then
		Debug("Consio Blocks folder not found")
		return
	end

	local functions = {}	
	local connections = {}
	local UserInputService = game:GetService("UserInputService")

	if Vyn then
		Vyn:Listen("Consio", function(path, modelname, state)
			Debug("Got request from server")
			Debug(`Got arguments {modelname}, {state}`)

			if state then
				local model = workspace:FindFirstChild(modelname)

				if model then
					for _, block in pairs(model:GetDescendants()) do
						if functions:GetBlockByName(block.Name) then
							local ganger: Instance = functions:GetBlockByName(block.Name)
							local keys = ganger:GetChildren()
							local blockid = ganger:GetAttribute("Blockid")

							if blockid then
								if keys then
									local connection = UserInputService.InputBegan:Connect(function(input, processed)
										if not processed then
											for _, key in pairs(keys) do
												if key:IsA("StringValue") then
													if Enum.KeyCode[string.split(key.Name, ".")[3]] == input.KeyCode then
														Debug("Asking server to run function")
														Vyn:Fire("Consio", ganger.Name, input.KeyCode)
													end
												end
											end
										end
									end)
									table.insert(connections, connection)  -- Store the connection
								end
							end
						end
					end
				else
					Debug("Model not found")
				end
			else
				Debug("Got request to stop")
				for _, conn in pairs(connections) do
					conn:Disconnect()
				end
				connections = {}  -- Clear connections after disconnecting
			end
		end)
	end

	function functions:GetAllBlocks()
		return folder:GetDescendants()
	end

	function functions:GetBlockById(id: number)
		for _, block in pairs(functions:GetAllBlocks()) do
			if block:GetAttribute("Blockid") == id then
				return block
			end
		end
	end

	function functions:GetBlockByName(name: string)
		for _, block in pairs(functions:GetAllBlocks()) do
			if block.Name == name then
				return block
			end
		end
	end

	function functions:BlockHasId(block: Instance, id: number)
		return block:GetAttribute("Blockid") == id
	end

	function functions:GetBlockId(block: Instance)
		return block:GetAttribute("Blockid")
	end

	function functions:HasIdentifier(block: Instance)
		return block:GetAttribute("Blockid") ~= nil
	end

	return functions
end

if RunService:IsServer() then
	return consio.Server
else
	return consio.Client
end
