# Herdr Overview for Omarchy

A native Omarchy bar widget for monitoring Herdr agents across local and saved SSH machines. The panel follows **Machine → Space → Worktree → Agent**, with global counts and short task summaries. Its bar icon changes shape and color for running work, output to review, input needed, idle, and connection errors.

## Requirements

- Omarchy with shell plugin support
- Herdr installed and available on `PATH`
- Python 3.10 or newer

Remote machines must already be configured in Herdr. The widget reads enabled profiles from `herdr machine list --json`; it never creates a connection profile or changes an agent.

## Install

```bash
git clone https://github.com/AlexR1712/herdr-omarchy-plugin.git
cd herdr-omarchy-plugin
bash install.sh
```

The installer validates the manifest, copies the plugin to `~/.config/omarchy/plugins/herdr-overview/`, and places its icon beside Omarchy's Agents widget on the right side of the bar. Run the same command after pulling an update.

## Read the overview

| Signal | Herdr state | Meaning |
| --- | --- | --- |
| Running | `working` | An agent is executing. |
| Review | `done` | The agent finished and its output has not been seen. |
| Waiting | `blocked` | The agent needs input or a decision. |
| Idle | `idle` | The agent is ready and has been seen. |
| Other | `unknown` | Herdr cannot classify the state confidently. |

Click the icon to open the panel; middle-click to refresh. The bar polls every 12 seconds, or every 5 seconds while the panel is open. The small animation runs only while the panel is open and work is active.

A machine that does not respond appears as unavailable; a timeout is labeled `TIMED OUT` because it does not prove the machine is offline. Global counts include only machines that responded, and the panel marks the snapshot as partial. The plugin queries remote machines in parallel with a 30-second timeout per machine to allow a cold SSH connection and Herdr remote bridge to start. A short-lived per-user cache prevents separate bar instances from repeating the same SSH queries; concurrent instances wait for that refresh to complete.

Project and task names come directly from Herdr and keep their original language. All interface labels are in English.

## Verify locally

```bash
python3 -m unittest discover -s tests -v
omarchy plugin validate .
```

The helper is read-only: it calls Herdr's snapshot and machine-list commands and stores a short-lived status cache under the user's runtime or cache directory. It does not read agent terminal output or send input to agents.
