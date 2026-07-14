# JiraBoard

A little macOS desktop widget that keeps your Jira board in the corner of your
screen. It shows the issues assigned to you, grouped by board column, so you can
glance at what's on your plate without opening a browser tab and waiting for Jira
to load.

I built it because I kept alt-tabbing to Jira just to remember what I was supposed
to be doing. Now it just sits on the desktop. Click a task and it opens in Jira;
use the arrows at the bottom to flip between columns or page through a long list.
That's the whole thing.

## Preview

<table>
  <tr>
    <td width="50%"><video src="https://github.com/user-attachments/assets/a3980106-b24a-4047-8fc9-447c2624a833" muted></video></td>
    <td width="50%"><video src="https://github.com/user-attachments/assets/b638d4ee-c09e-4697-8e31-8de5eb076820" muted></video></td>
  </tr>
</table>

## Stack

- **SwiftUI** for the widget UI and the (tiny, headless) host app.
- **WidgetKit** — it's a real desktop widget, not an app window pretending to be one.
- **App Intents** — the configuration sheet and the paging buttons are both App Intents.
- Plain **URLSession** against the Jira Cloud REST + Agile APIs. No third-party dependencies.
- Xcode project with a hand-written `project.pbxproj` (no xcodegen/SPM), macOS 14+.

## How it works

There are three pieces:

- **The host app** is headless — no window, no dock icon. Its only job is to catch
  the URL a widget tap sends and hand it to your browser, so clicking a task opens
  the issue in Jira. Everything else lives in the widget.
- **The widget** talks to Jira on a timeline. It maps your board's columns to their
  Jira statuses (`/rest/agile/1.0/board/{id}/configuration`), pulls the issues
  assigned to you (`POST /rest/api/3/search/jql` with `assignee = currentUser()`),
  and caches the result for 15 minutes so it isn't hammering the API on every refresh.
- **Configuration lives in the widget itself** (right-click → *Edit Widget*): your
  Jira URL, email, API token, then a board and the columns you want. The board and
  column pickers are populated live from your account as you fill the fields in.

Widgets can't scroll, so navigation is done with buttons: `‹ / ›` switch board
columns, `↑ / ↓` page through the tasks in a column. Large size only — it's the one
that actually fits a useful number of rows.

## A note about free Apple accounts

This is the part that shaped most of the design. On a **free (Personal) Apple
account** you don't get App Groups, and a widget has to run sandboxed — which means
the app and the widget **can't share a file or a container**. The usual pattern
(app writes the config, widget reads it) is off the table.

So the config doesn't live in the app at all. It lives in the widget's own
configuration (that *Edit Widget* sheet), which WidgetKit hands directly to the
widget's timeline provider — no shared storage needed. That's why setup happens on
the widget and not in some settings window.

One consequence worth knowing: a widget launched from Xcode is temporary and
disappears when you stop the debug session. To keep it around, build a Release
`.app` and drop it in `/Applications` (see below).

## Install (prebuilt)

Grab `JiraBoard.zip` from the [latest release](../../releases/latest), unzip it, and
move `JiraBoard.app` into `/Applications`. The app is signed with a free Apple
Development certificate, so Gatekeeper will grumble the first time:

```bash
xattr -dr com.apple.quarantine /Applications/JiraBoard.app
open /Applications/JiraBoard.app
```

Then add the widget: right-click the desktop → **Edit Widgets** → find **Jira
Board** and drag it onto the desktop.

## Setup

Right-click the widget → **Edit Widget** to open the settings sheet:

<img width="379" height="376" alt="Widget Setup" src="https://github.com/user-attachments/assets/00c6fc4c-2195-4ee1-9b2c-a218fe304d89" />
<img width="410" height="456" alt="Widget Setup Menu" src="https://github.com/user-attachments/assets/612cb912-0420-4fbf-bbc5-0fd878c916e7" />


Fill it in top to bottom:

| Field | What to put |
|-------|-------------|
| Jira site URL | your Jira address, e.g. `https://team.atlassian.net` |
| Account email | the email of your Atlassian account |
| API token | [create one here](https://id.atlassian.com/manage-profile/security/api-tokens) |
| Board | pick from the dropdown (loads once the fields above are filled) |
| Columns to show | tick the columns you want to see |

The board and column lists are fetched live from your account, so fill the URL,
email and token first — the dropdowns populate from those. Once a board is picked
and at least one column is ticked, the widget starts showing your tasks.

## Build from source

The most reliable way to run it is to build it under your own Apple ID:

```bash
open JiraBoard.xcodeproj                        # pick your Team on both targets
TEAM=<your-team-id> Scripts/build-release.sh    # signed Release build → dist/
Scripts/install.sh                              # copies to /Applications
```

Without `TEAM` the build is ad-hoc and only runs on the machine that built it. With
your Team ID it's signed with your Apple Development certificate.

Because that certificate is free (not a paid Developer ID), the prebuilt `.app`
runs on other Macs only after the `xattr` step above. Shipping something that opens
for anyone with no fuss would need Developer ID signing and notarization, which a
free account can't do — so building your own copy is the honest path.
