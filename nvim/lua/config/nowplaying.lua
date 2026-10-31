-- Currently playing media (macOS) for the status line, left of the clock; on/off with
-- vim.g.now_playing. `media-control` (brew install media-control) sees every player:
-- Music, Spotify, browsers, Podcasts... Without it, Music and Spotify are asked directly.
local M = {}

local text = "" -- "Artist – Title" while something plays, else ""
local timer, busy

-- JavaScript for Automation: unlike AppleScript, it doesn't ask where an app is when it isn't installed
local jxa = [[
function run() {
  for (const name of ["Spotify", "Music"]) {
    try {
      const app = Application(name);
      if (app.running() && app.playerState() === "playing") {
        const t = app.currentTrack();
        return t.artist() + "\t" + t.name();
      }
    } catch (e) {}
  }
  return "";
}
]]

local function join(artist, title)
  if not title or title == "" then return "" end
  if artist and artist ~= "" then return artist .. " – " .. title end
  return title
end

local function parse(res)
  if res.code ~= 0 then return "" end
  if vim.fn.executable("media-control") == 1 then
    local ok, info = pcall(vim.json.decode, res.stdout)
    if not ok or type(info) ~= "table" or not info.playing then return "" end
    return join(info.artist, info.title)
  end
  local artist, title = vim.trim(res.stdout):match("^(.-)\t(.*)$")
  return join(artist, title)
end

local function poll()
  if busy or not vim.g.now_playing then return end
  busy = true
  local cmd = vim.fn.executable("media-control") == 1 and { "media-control", "get" }
    or { "osascript", "-l", "JavaScript", "-e", jxa }
  vim.system(cmd, { text = true, timeout = 5000 }, function(res)
    local new = parse(res)
    vim.schedule(function()
      busy = false
      if new ~= text then
        text = new
        vim.cmd.redrawstatus()
      end
    end)
  end)
end

-- room left in the status line, roughly: the editor width minus the other sections
local function free_width()
  local w = vim.fn.strdisplaywidth
  local used = 60 -- mode, diff, encoding, position, clock and the padding around them
    + w(vim.fn.expand("%:t")) + w(vim.bo.filetype) + w(vim.b.gitsigns_head or "")
    + w(require("claude").status())
  return vim.o.columns - used
end

-- the status line component; empty (and hidden) when nothing plays or it doesn't fit
function M.status()
  if not vim.g.now_playing or vim.fn.has("mac") == 0 then return "" end
  if not timer then
    timer = vim.uv.new_timer()
    timer:start(0, 3000, vim.schedule_wrap(poll))
  end
  if text == "" then return "" end
  local room = math.min(free_width(), 60)
  if room < 15 then return "" end
  local s = "♪ " .. text
  if vim.fn.strdisplaywidth(s) > room then
    s = vim.fn.strcharpart(s, 0, room - 1) .. "…"
  end
  return s
end

return M
