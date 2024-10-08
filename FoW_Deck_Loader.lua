-- We import a JSON parsing library because Tabletop Simulator's default JSON
-- parsing implementation causes serious lag spikes and crashes when handling
-- large objects.
--
-- From https://github.com/rxi/json.lua/blob/master/json.lua
--
--
-- json.lua
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local DEBUG = false

local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end


local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
  return "null"
end


local function encode_table(val, stack)
  local res = {}
  stack = stack or {}

  -- Circular reference?
  if stack[val] then error("circular reference") end

  stack[val] = true

  if rawget(val, 1) ~= nil or next(val) == nil then
    -- Treat as array -- check keys are valid and it is not sparse
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then
        error("invalid table: mixed or invalid key types")
      end
      n = n + 1
    end
    if n ~= #val then
      error("invalid table: sparse array")
    end
    -- Encode
    for i, v in ipairs(val) do
      table.insert(res, encode(v, stack))
    end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"

  else
    -- Treat as an object
    for k, v in pairs(val) do
      if type(k) ~= "string" then
        error("invalid table: mixed or invalid key types")
      end
      table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end


-- -*- coding: utf-8 -*-
--
-- Simple JSON encoding and decoding in pure Lua.
--
-- Copyright 2010-2017 Jeffrey Friedl
-- http://regex.info/blog/
-- Latest version: http://regex.info/blog/lua/json
--
-- This code is released under a Creative Commons CC-BY "Attribution" License:
-- http://creativecommons.org/licenses/by/3.0/deed.en_US
--
-- It can be used for any purpose so long as:
--    1) the copyright notice above is maintained
--    2) the web-page links above are maintained
--    3) the 'AUTHOR_NOTE' string below is maintained
--
-- local VERSION = '20170927.26' -- version history at end of file
-- local AUTHOR_NOTE = "-[ JSON.lua package by Jeffrey Friedl (http://regex.info/blog/lua/json) version 20170927.26 ]-"

--
-- The 'AUTHOR_NOTE' variable exists so that information about the source
-- of the package is maintained even in compiled versions. It's also
-- included in OBJDEF below mostly to quiet warnings about unused variables.
--
-- local OBJDEF = {
--    VERSION      = VERSION,
--    AUTHOR_NOTE  = AUTHOR_NOTE,
-- }

local function object_or_array(T)
   --
   -- We need to inspect all the keys... if there are any strings, we'll convert to a JSON
   -- object. If there are only numbers, it's a JSON array.
   --
   -- If we'll be converting to a JSON object, we'll want to sort the keys so that the
   -- end result is deterministic.
   --
   local string_keys = { }
   local number_keys = { }
   local number_keys_must_be_strings = false
   local maximum_number_key

   for key in pairs(T) do
      if type(key) == 'string' then
         table.insert(string_keys, key)
      elseif type(key) == 'number' then
         table.insert(number_keys, key)
         if key <= 0 or key >= math.huge then
            number_keys_must_be_strings = true
         elseif not maximum_number_key or key > maximum_number_key then
            maximum_number_key = key
         end
      elseif type(key) == 'boolean' then
         table.insert(string_keys, tostring(key))
      else
         error("can't encode table with a key of type " .. type(key))
      end
   end

   if #string_keys == 0 and not number_keys_must_be_strings then
      --
      -- An empty table, or a numeric-only array
      --
      if #number_keys > 0 then
         return nil, maximum_number_key -- an array
      elseif tostring(T) == "JSON array" then
         return nil
      elseif tostring(T) == "JSON object" then
         return { }
      else
         -- have to guess, so we'll pick array, since empty arrays are likely more common than empty objects
         return nil
      end
   end

   local map
   if #number_keys > 0 then

      --
      -- Have to make a shallow copy of the source table so we can remap the numeric keys to be strings
      --
      map = { }
      for key, val in pairs(T) do
         map[key] = val
      end

      --
      -- Throw numeric keys in there as strings
      --
      for _, number_key in ipairs(number_keys) do
         local string_key = tostring(number_key)
         if map[string_key] == nil then
            table.insert(string_keys , string_key)
            map[string_key] = T[number_key]
         else
            error("conflict converting table with mixed-type keys into a JSON object: key " .. number_key .. " exists both as a string and a number.")
         end
      end
   end

   return string_keys, nil, map
end


local function new_encode_table(val, stack)
    local res = {}
    stack = stack or {}

    local object_keys, maximum_number_key, map = object_or_array(val)
    if maximum_number_key then
       -- An array
       local ITEMS = { }
       for i = 1, maximum_number_key do
          table.insert(res, encode(val[i], stack))
       end
       stack[val] = nil
       return "["  .. table.concat(res, ",")  .. "]"
    elseif object_keys then
       -- An object
      local TT = map or val
      local PARTS = { }
      for _, key in ipairs(object_keys) do
         table.insert(res, encode(key, stack) .. ":" .. encode(TT[key], stack))
      end
      stack[val] = nil
      return "{" .. table.concat(res, ",") .. "}"
    else
       -- An empty array/object... we'll treat it as an array, though it should really be an option
       stack[val] = nil
       return "[]"
    end
end


local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
  -- Check for NaN, -inf and inf
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("unexpected number value '" .. tostring(val) .. "'")
  end
  return string.format("%.14g", val)
end


local type_func_map = {
  [ "nil"     ] = encode_nil,
  [ "table"   ] = new_encode_table,
  [ "string"  ] = encode_string,
  [ "number"  ] = encode_number,
  [ "boolean" ] = tostring,
}


encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val, stack)
  end
  error("unexpected type '" .. t .. "'")
end


function jsonencode(val)
  return ( encode(val) )
end


-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_number_b16(s)
    -- tonumber raises when given the empty string, if the base is not 10...
    if not s or s == '' then
        return nil
    end

    return tonumber(s, 16)
end


local function parse_unicode_escape(s)
  local n1 = parse_number_b16( s:sub(1,4) )
  local n2 = parse_number_b16( s:sub(7, 10) )

  -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end


local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 34 then -- `"`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end


local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end


local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}


parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function jsondecode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end





------ CONSTANTS

if(DEBUG) then
  FORCEOFWIND_BASE = "http://localhost:1337"
  FORCEOFWIND_DECK_API_BASE = "http://localhost:1337/api/deck/"
  FORCEOFWIND_URL_MATCH = "localhost:1337"
  FORCEOFWIND_URL_ID_MATCH = "localhost:1337/view_decklist/(%d*)/"
  FORCEOFWIND_BASE_IMG_URL = FORCEOFWIND_BASE
else
  FORCEOFWIND_BASE = "https://forceofwind.online"
  FORCEOFWIND_DECK_API_BASE = "https://forceofwind.online/api/deck/"
  FORCEOFWIND_URL_MATCH = "forceofwind%.online"
  FORCEOFWIND_URL_ID_MATCH = "forceofwind%.online/view_decklist/(%d*)/"
  FORCEOFWIND_BASE_IMG_URL = ""
end

FORCEOFWIND_URL_SUFFIX = "/"

DEFAULT_CARDBACK = "https://i.imgur.com/QRiof4H.jpeg"
DEFAULT_LANGUAGE = "en"

LANGUAGES = {
    ["en"] = "en",
}

UI_LABEL_SEARCH_FIELD = 'Decklist Url from Force of Wind.....'

------ UI IDs
UI_ADVANCED_PANEL = "MTGDeckLoaderAdvancedPanel"
UI_CARD_BACK_INPUT = "MTGDeckLoaderCardBackInput"
UI_LANGUAGE_INPUT = "MTGDeckLoaderLanguageInput"
UI_FORCE_LANGUAGE_TOGGLE = "MTGDeckLoaderForceLanguageToggleID"

------ GLOBAL STATE
lock = false
playerColor = nil
deckSource = nil
advanced = false
cardBackInput = ""
languageInput = ""
forceLanguage = false
enableTokenButtons = false
blowCache = false
pngGraphics = true
spawnEverythingFaceDown = false

------ UTILITY
local function trim(s)
    if not s then return "" end

    local n = s:find"%S"
    return n and s:match(".*%S", n) or ""
end

local function iterateLines(s)
    if not s or string.len(s) == 0 then
        return ipairs({})
    end

    if s:sub(-1) ~= '\n' then
        s = s .. '\n'
    end

    local pos = 1
    return function ()
        if not pos then return nil end

        local p1, p2 = s:find("\r?\n", pos)

        local line
        if p1 then
            line = s:sub(pos, p1 - 1)
            pos = p2 + 1
        else
            line = s:sub(pos)
            pos = nil
        end

        return line
    end
end

local function underline(s)
    if not s or string.len(s) == 0 then
        return ""
    end

    return s .. '\n' .. string.rep('-', string.len(s)) .. '\n'
end

local function shallowCopyTable(t)
    if type(t) == 'table' then
        local copy = {}
        for key, val in pairs(t) do
            copy[key] = val
        end

        return copy
    end

    return {}
end

local function readNotebookForColor(playerColor)
    for i, tab in ipairs(Notes.getNotebookTabs()) do
        if tab.title == playerColor and tab.color == playerColor then
            return tab.body
        end
    end

    return nil
end

local function valInTable(table, v)
    for _, value in ipairs(table) do
        if value == v then
            return true
        end
    end

    return false
end

local function printErr(s)
    printToColor(s, playerColor, {r=1, g=0, b=0})
end

local function printInfo(s)
    printToColor(s, playerColor)
end

local function stringToBool(s)
    -- It is truly ridiculous that this needs to exist.
    return (string.lower(s) == "true")
end

------ CARD SPAWNING
local function jsonForCardFace(face, position, flipped)
    local rotation = self.getRotation()

    local rotZ = rotation.z
    if flipped then
        rotZ = math.fmod(rotZ + 180, 360)
    end

    local json = {
        Name = "Card",
        Transform = {
            posX = position.x,
            posY = position.y,
            posZ = position.z,
            rotX = rotation.x,
            rotY = rotation.y,
            rotZ = rotZ,
            scaleX = 1,
            scaleY = 1,
            scaleZ = 1
        },
        Nickname = face.name,
        Description = face.oracleText,
        Locked = false,
        Grid = true,
        Snap = true,
        IgnoreFoW = false,
        MeasureMovement = false,
        DragSelectable = true,
        Autoraise = true,
        Sticky = true,
        Tooltip = true,
        GridProjection = false,
        HideWhenFaceDown = true,
        Hands = true,
        CardID = 2440000,
        SidewaysCard = false,
        CustomDeck = {},
        LuaScript = "",
        LuaScriptState = "",
     }

     json.CustomDeck["24400"] = {
         FaceURL = face.imageURI,
         BackURL = getCardBack(),
         NumWidth = 1,
         NumHeight = 1,
         BackIsHidden = true,
         UniqueBack = false,
         Type = 0
     }

     return json
end

-- Spawns the given card [faces] at [position].
-- Card will be face down if [flipped].
-- Calls [onFullySpawned] when the object is spawned.
local function spawnCard(faces, position, flipped, onFullySpawned)
    if not faces or not faces[1] then
        faces = {{
            name = card.name,
            oracleText = "Card not found",
            imageURI = "https://vignette.wikia.nocookie.net/yugioh/images/9/94/Back-Anime-2.png/revision/latest?cb=20110624090942",
        }}
    end

    -- Force flipped if the user asked for everything to be spawned face-down
    if spawnEverythingFaceDown then
        flipped = true
    end

    local jsonFace1 = jsonForCardFace(faces[1], position, flipped)

    if #faces > 1 then
        jsonFace1.States = {}
        for i=2,(#(faces)) do
            local jsonFaceI = jsonForCardFace(faces[i], position, flipped)

            jsonFace1.States[tostring(i)] = jsonFaceI
        end
    end

    local cardObj = spawnObjectJSON({json = JSON.encode(jsonFace1)})

    onFullySpawned(cardObj)

    return cardObj
end

-- Spawns a deck named [name] containing the given [cards] at [position].
-- Deck will be face down if [flipped].
-- Calls [onFullySpawned] when the object is spawned.
local function spawnDeck(cards, name, position, flipped, onFullySpawned, onError)
    local cardObjects = {}

    local sem = 0
    local function incSem() sem = sem + 1 end
    local function decSem() sem = sem - 1 end

    for _, card in ipairs(cards) do
        for i=1,(card.count or 1) do
            if not card.faces or not card.faces[1] then
                card.faces = {{
                    name = card.name,
                    oracleText = "Card not found",
                    imageURI = "https://vignette.wikia.nocookie.net/yugioh/images/9/94/Back-Anime-2.png/revision/latest?cb=20110624090942",
                }}
            end

            incSem()
            spawnCard(card.faces, position, flipped, function(obj)
                table.insert(cardObjects, obj)
                decSem()
            end)
        end
    end

    Wait.condition(
        function()
            local deckObject

            if cardObjects[1] and cardObjects[2] then
                -- deckObject = cardObjects[1].putObject(cardObjects[2])
                if success and deckObject then
                    deckObject.setPosition(position)
                    deckObject.setName(name)
                    deckObject.setDescription(name)
                else
                    deckObject = cardObjects[1]
                end
            else
                deckObject = cardObjects[1]
            end
            onFullySpawned(deckObject)
        end,
        function() return (sem == 0) end,
        5,
        function() onError("Error collating deck... timed out.") end
    )
end

local function getPositionForZone(x, y, z)
    return {x, y, z}
end

-- Queries for the given card IDs, collates deck, and spawns objects.
local function loadDeck(cards, deckName, onComplete, onError)
    local xDecrease = -0.7286
    local xPos = 1.47
    local yPos = 0.2
    local zPos = 0.0

    local positions = {}
    local lastX = xPos
    local zoneDecks = {}
    local zoneIndex = {}
    local indexZone = {}
    local i = 1

    printInfo("Preparing Deck... :")

    for _, card in ipairs(cards) do
        if zoneIndex[card.zone] == nil then
            zoneIndex[card.zone] = i
            indexZone[i] = card.zone
            i = i + 1
        end

        local currZoneIndex = zoneIndex[card.zone]

        if positions[currZoneIndex] == nil then
            positions[currZoneIndex] = getPositionForZone(lastX, yPos, zPos)
            lastX = lastX + xDecrease
        end

        if zoneDecks[currZoneIndex] == nil then
            zoneDecks[currZoneIndex] = {}
        end

        local nestedTable = zoneDecks[currZoneIndex]
        nestedTable[#nestedTable+1] = card
        zoneDecks[currZoneIndex] = nestedTable
    end

    local sem = tablelength(zoneDecks)
    local function decSem() sem = sem - 1 end

    for index, zoneDeck in ipairs(zoneDecks) do
        notRuler = string.match(indexZone[index], "ruler") == nil and string.match(indexZone[index], "Ruler") == nil
        spawnDeck(zoneDeck, indexZone[index], self.positionToWorld(positions[index]), notRuler,
          function() -- onSuccess
              decSem()
          end,
          function(e) -- onError
              printErr(e)
              decSem()
          end
        )
    end
    Wait.condition(
            function() onComplete() end,
            function() return (sem == 0) end,
            10,
            function() onError("Error spawning deck objects... timed out.") end
        )
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

local function parseDeckIDForceOfWind(s)
    -- NOTE: need to do this in multiple parts because TTS uses an old version
    -- of lua with hilariously sad pattern matching
    return s:match(FORCEOFWIND_URL_ID_MATCH)
end

local function queryDeckForceOfWind(slug, onSuccess, onError)
    if not slug or string.len(slug) == 0 then
        onError("Invalid fow deck slug: " .. dump(slug))
        return
    end

    local url = FORCEOFWIND_DECK_API_BASE .. slug .. FORCEOFWIND_URL_SUFFIX

    printInfo("Fetching decklist from fowind... :")

    WebRequest.get(url, function(webReturn)
        if webReturn.error then
            if string.match(webReturn.error, "(404)") then
                onError("Deck not found. Is it public?")
            else
                onError("Web request error: " .. webReturn.error)
            end
            return
        elseif webReturn.is_error then
            onError("Web request error: unknown")
            return
        elseif string.len(webReturn.text) == 0 then
            onError("Web request error: empty response")
            return
        end

        local success, data = pcall(function() return jsondecode(webReturn.text) end)

        if not success then
            onError("Failed to parse JSON response from force of wind.")
            return
        elseif not data then
            onError("Empty response from force of wind.")
            return
        elseif not data.name then
            onError("Empty response from force of wind. Did you enter a valid deck URL?")
            return
        end

        local deckName = data.name
        local cards = {}

        for name, cardData in pairs(data.cards or {}) do
            if cardData then
                faces = {}
                faces[1] =
                {
                    imageURI = FORCEOFWIND_BASE_IMG_URL .. cardData.img,
                    name = cardData.name,
                    oracleText = cardData.oracleText
                }

                for _, face in pairs(cardData.otherFaces or {}) do
                  table.insert(faces, {imageURI = FORCEOFWIND_BASE_IMG_URL .. face.img, name = face.name, oracleText = face.oracleText})
                end

                table.insert(cards, {
                    name = cardData.name,
                    count = cardData.quantity,
                    cardId = cardData.id,
                    zone = cardData.zone,
                    otherFaces = cardData.otherFaces,
                    oracleText = cardData.oracleText,
                    faces = faces
                })
            end
        end

        onSuccess(cards, deckName)
    end)
end

function importDeck()
    if lock then
        log("Error: Deck import started while importer locked.")
    end

    local deckURL = getDeckInputValue()

    printInfo(deckURL)

    local deckID, queryDeckFunc
    if deckSource == DECK_SOURCE_URL then
      if string.len(deckURL) == 0 then
          printInfo("Please enter a deck URL.")
          return 1
      end

      if string.match(deckURL, FORCEOFWIND_URL_MATCH) then
        queryDeckFunc = queryDeckForceOfWind
        deckID = parseDeckIDForceOfWind(deckURL)
      else
        printInfo("Unknown deck site, sorry! Please input a valid force of wind decklist!")
        return 1
      end
    else
        log("Error. Unknown deck source: " .. deckSource or "nil")
        return 1
    end

    lock = true
    printToAll("Starting deck import...")

    local function onError(e)
        printErr(e)
        printToAll("Deck import failed.")
        lock = false
    end

    queryDeckFunc(deckID,
        function(cardIDs, deckName)
            loadDeck(cardIDs, deckName,
                function()
                    printToAll("Deck import complete!")
                    lock = false
                end,
                onError
            )
        end,
        onError
    )

    return 1
end

------ UI
local function drawUI()
    local _inputs = self.getInputs()
    local deckURL = ""

    if _inputs ~= nil then
        for i, input in pairs(self.getInputs()) do
            if input.label == UI_LABEL_SEARCH_FIELD then
                deckURL = input.value
            end
        end
    end
    self.clearInputs()
    self.clearButtons()
    self.createInput({
        input_function = "onLoadDeckInput",
        function_owner = self,
        label          = UI_LABEL_SEARCH_FIELD,
        alignment      = 2,
        position       = {x=0, y=0.1, z=0.78},
        width          = 2000,
        height         = 100,
        font_size      = 60,
        validation     = 1,
        value = deckURL,
    })

    self.createButton({
        click_function = "onLoadDeckURLButton",
        function_owner = self,
        label          = "Load Deck (URL)",
        position       = {-1, 0.1, 1.15},
        rotation       = {0, 0, 0},
        width          = 850,
        height         = 160,
        font_size      = 80,
        color          = {0.5, 0.5, 0.5},
        font_color     = {r=1, b=1, g=1},
        tooltip        = "Click to load deck from URL",
    })
end

function getDeckInputValue()
    for i, input in pairs(self.getInputs()) do
        if input.label == UI_LABEL_SEARCH_FIELD then
            return trim(input.value)
        end
    end

    return ""
end

function onLoadDeckInput(_, _, _) end

function onLoadDeckURLButton(_, pc, _)
    if lock then
        printToColor("Another deck is currently being imported. Please wait for that to finish.", pc)
        return
    end

    playerColor = pc
    deckSource = DECK_SOURCE_URL

    startLuaCoroutine(self, "importDeck")
end

function getCardBack()
    if not cardBackInput or string.len(cardBackInput) == 0 then
        return DEFAULT_CARDBACK
    else
        return cardBackInput
    end
end

function mtgdl__onCardBackInput(_, value, _)
    cardBackInput = value
end

function getLanguageCode()
    if not languageInput or string.len(languageInput) == 0 then
        return DEFAULT_LANGUAGE
    else
        local code = LANGUAGES[string.lower(trim(languageInput))]

        return (code or DEFAULT_LANGUAGE)
    end
end

function mtgdl__onLanguageInput(_, value, _)
    languageInput = value
end

function mtgdl__onForceLanguageInput(_, value, _)
    forceLanguage = stringToBool(value)
end

function mtgdl__onTokenButtonsInput(_, value, _)
    enableTokenButtons = stringToBool(value)
end

function mtgdl__onBlowCacheInput(_, value, _)
    blowCache = stringToBool(value)
end

function mtgdl__onPNGGraphicsInput(_, value, _)
    pngGraphics = stringToBool(value)
end

function mtgdl__onFaceDownInput(_, value, _)
    spawnEverythingFaceDown = stringToBool(value)
end

------ TTS CALLBACKS
function onLoad()
    self.setName("FoW Deck Loader")

    self.setDescription(
    [[
Enter your deck URL from force of wind!
]])

    drawUI()
end