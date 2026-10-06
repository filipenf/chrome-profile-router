# Chrome Profile Router

Open each website in the right Chromium profile. `x.com` and `hey.com` can open in your personal profile while
everything else opens in your work profile. You control the rules in one small file.

## Install

You need [Omarchy](https://omarchy.org/) and Chromium.

Copy and paste these lines into a terminal, one block at a time:

```bash
omarchy plugin add https://github.com/filipenf/chrome-profile-router.git --enable --yes
```

```bash
~/.config/omarchy/plugins/chrome-profile-router/install.sh
```

Done. Click any link and it opens in the profile you chose.

## Prefer a window?

Open your app launcher and start **Chrome Profile Router Settings**. It shows every rule as a row you can
edit, delete, or add to — plus the default profile at the bottom. Press **Save** and new links use the
new rules at once. (Same window from a terminal: `omarchy-shell shell summon chrome-profile-router "{}"`.)

## Choose which site opens where

Open this file in any text editor:

```
~/.config/omarchy/plugins/chrome-profile-router/config.json
```

It looks like this:

```json
{
  "default_profile": "Default",
  "mappings": {
    "x.com": "Profile 1",
    "hey.com": "Profile 1",
    "github.com": "Default"
  }
}
```

- To send a site to a profile, add one line: `"example.com": "Profile 2",`
- To change the fallback profile, edit `default_profile`.
- Profile names must match your Chromium profiles exactly. Find them at `chrome://version` (the **Profile Path** ends
  with the folder name, e.g. `Default` or `Profile 1`).

Save the file. There is nothing to restart. New links use the new rules at once.

## Change rules from the terminal

No text editor needed. These commands update `config.json` for you:

```bash
# Send a site to a profile (adds the rule, or updates it if it exists)
omarchy-shell chrome-profile-router setProfile example.com "Profile 1"

# Change the fallback profile for everything without a rule
omarchy-shell chrome-profile-router setDefault "Profile 2"
```

Check the result with the dry run:

```bash
omarchy-shell chrome-profile-router profileFor 'https://example.com/page'
```

## Check it works (no browser opens)

```bash
omarchy-shell chrome-profile-router profileFor 'https://x.com/home'
omarchy-shell chrome-profile-router profileFor 'https://github.com/omarchy'
```

Each line prints the profile that URL would open in. Then try a real link:

```bash
xdg-open 'https://x.com/home'
```

## How it works

1. The `install.sh` script makes Chrome Profile Router your default browser.
2. Every clicked link runs a tiny script that asks the plugin: which profile?
3. The plugin matches the link against your list and opens Chromium with that profile.

## If links open in the wrong place

| Problem                               | Fix                                                                                                                                        |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| A site uses the wrong profile         | Add that site to `config.json` and save                                                                                                    |
| Nothing happens on click              | Run `omarchy-shell chrome-profile-router ping` — it should print `ok`. If not, run `omarchy-shell shell rescanPlugins`                     |
| `profileFor` prints the wrong profile | Check spelling of the domain and profile name in `config.json` (capitals do not matter for domains, but they do for profile names) |
| You want Chromium back as default     | Run `xdg-settings set default-web-browser chromium.desktop`                                                                                |

## Remove

```bash
xdg-settings set default-web-browser chromium.desktop
omarchy plugin disable chrome-profile-router
```

Optional: `omarchy plugin remove chrome-profile-router` deletes it completely.
