# StoryTeller Auto

StoryTeller Auto drives the StoryTeller addon through a script one line at a time, so a story written
as `/s` and `/e` lines can be read out with a single key press per line. There are no timers: this
client blocks chat sent from addon timers, so reading is driven by real input instead.

## Requirements

- StoryTeller (required)
- Titan Panel (optional - adds a small panel button)

## Install

1. Copy the `StoryTellerAuto` folder into `World of Warcraft\Interface\AddOns\`.
2. Restart the game or type `/reload`.

## Bundled stories

The addon ships with one story: **Barrens Chat: Chuck Norris Facts**. Other stories are meant to be
added by whoever installs the addon - see below.

## Commands

| Command | What it does |
| --- | --- |
| `/storylist` or `/stories` | open the story picker |
| `/storyauto play <n>` | load story number `n` from `/storyauto list` |
| `/storyauto list` | list every story the picker shows |
| `/storyauto save <name>` | keep the text currently in StoryTeller's window as your own story |
| `/storyauto delete <n>` | remove one of your own saved stories |
| `/storyauto next` | speak the next line (also works from the Next Line button) |
| `/storyauto bind F8` | bind one key that speaks a line per press |
| `/storyauto status` | show the current line key |
| `/storyauto test` | diagnostics: what StoryTeller has loaded, where the next line goes |
| `/storyauto help` | the command list in game |

The first time the addon loads it binds **F8** to the line key if nothing is bound yet and F8 is
free. If F8 is taken, use `/storyauto bind <key>` or the **Bind F8** button in the picker; the key
speaks one line per press.

## Add your own stories

### In game (easiest)

1. Open the story picker with `/storylist`.
2. Click **Add Story** - the editor opens with whatever text is currently in StoryTeller's window
   (paste a story there first if it is empty), one script line per line.
3. Give it a name and click **Save**. The story is stored in your SavedVariables and shows up in the
   picker and `/storyauto list` marked `(yours)`. Addon updates never touch it.

You can also run `/storyauto save <name>` to save StoryTeller's current text without opening the
editor. Saving with an existing name updates that story. Bundled stories cannot be overwritten or
deleted.

## Managing your stories in the picker

| Action | How |
| --- | --- |
| Add a story | **Add Story** button (top right of the picker) |
| Edit a story | right-click it in the picker, then **Edit** |
| Delete a story | right-click it in the picker, then **Delete** |
| Rename a story | edit it and change the name before saving |

The editor has a name field and a scrolling script box. Editing loads the story back into the editor
with its name filled in; saving under the same name updates it, and saving under a new name renames
it. Only your own stories (marked `(yours)`) can be edited or deleted.

### By hand

Close the game, then edit
`WTF\Account\<ACCOUNT>\SavedVariables\StoryTellerAuto.lua` and add entries to `StoryTellerAutoDB.stories`:

```lua
StoryTellerAutoDB = {
	["stories"] = {
		{
			["title"] = "My Story",
			["lines"] = "/s Gather close.\n/e leans in.\n/s The road ends here.",
		},
	},
}
```

### As a story pack addon

Another addon can ship stories without touching this one: depend on `StoryTellerAuto` in its `.toc`
and append entries to the shared list after it loads.

```lua
-- MyStories\Stories.lua
local stories = _G.StoryTellerAutoStories or {}
_G.StoryTellerAutoStories = stories

table.insert(stories, {
	title = "My Story",
	lines = "/s Gather close.\n/e leans in.\n/s The road ends here.",
})
```

Each entry is `{ title = "...", lines = "..." }`, with `lines` holding the same text you would paste
into StoryTeller - one line per chat message, blank lines ignored.

## Line format

- `/s text` - say
- `/e text` - emote (with a space, describes your character)
- `/y`, `/p`, `/ra`, `/g`, `/o`, `/i`, `/w Name,` - other channels
- Anything without a slash is sent as say

Chat is limited to 255 characters per line, so keep lines short.

## Packaging a release

1. Ship only the `StoryTellerAuto` folder - `Stories.lua` in it contains just the bundled story.
2. Bump `## Version` in `StoryTellerAuto.toc`, `ADDON_VERSION` in `StoryTellerAuto.lua` and
   `TITAN_VERSION` in `Titan.lua` together.
3. Do not ship SavedVariables; user stories live in `WTF` and stay with the player.
