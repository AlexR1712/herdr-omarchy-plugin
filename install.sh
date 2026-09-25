#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target_dir="${HOME}/.config/omarchy/plugins/herdr-overview"

command -v omarchy >/dev/null || { echo "Omarchy is unavailable" >&2; exit 1; }
command -v herdr >/dev/null || { echo "Herdr is unavailable" >&2; exit 1; }
omarchy plugin validate "$source_dir"

install -d "$target_dir/bin"
install -m 644 "$source_dir/manifest.json" "$source_dir/BarWidget.qml" \
  "$source_dir/Panel.qml" "$source_dir/HerdrMark.qml" "$source_dir/README.md" "$target_dir/"
install -m 755 "$source_dir/bin/herdr-overview" "$target_dir/bin/herdr-overview"

omarchy-shell shell rescanPlugins
omarchy plugin enable herdr-overview --section right --before omarchy.agents
echo "Herdr Overview installed in $target_dir"
