# Quest Starter

A World of Warcraft addon for items that start quests, like a monster's head or a strange letter.

When one lands in your bags, a glowing **New quest! Click to start** button pops up. Click it, or press your key binding, and the quest opens and is accepted for you. You don't have to dig through your bags, right-click the item, and then press Accept.

It also accepts the quest window when you right-click a quest item in your bags yourself.

## Why one click and not fully automatic?

WoW doesn't let addons use items on their own (that's an anti-botting rule), so a real click or key press has to start it. Accepting the quest that opens is allowed, so that part is automatic.

## Using it

- **Click** the button, or set a key under **Options → Keybindings → AddOns → Quest Starter**.
- Hold **Shift** while it opens if you want to read the quest before accepting.
- **Right-click** the button to ignore an item, for example one whose quest you can't take yet.
- **Shift+drag** moves the button.

| Command | What it does |
|---|---|
| `/qs` | Show settings and help |
| `/qs accept` | Auto-accept on/off |
| `/qs button` | Pop-up button on/off |
| `/qs sound` | "New quest" sound on/off |
| `/qs reset` | Un-ignore items and move the button back |

The button can't change during combat (a WoW rule for secure buttons), so new items show up as soon as the fight ends.

## Install

Download the release zip and extract it into `World of Warcraft\_forever_\Interface\AddOns\`.

## Tests

`pip install lupa`, then run `python tests/test_queststarter.py`.
