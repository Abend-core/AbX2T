#!/usr/bin/env zsh

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

repo=$(cd -- "${0:A:h}/../.." && pwd)
workspace_root=$(cd -- "$repo/.." && pwd)
qt_project="$repo/src/X2tConverter/build/Qt/X2tSLN.pro"
runtime_script="$repo/build/scripts/prepare_runtime_macos.sh"
build_root="${BUILD_ROOT:-$workspace_root/output/macos-arm64/build/x2t}"
bin_root="${BIN_ROOT:-$workspace_root/output/macos-arm64/bin}"
jobs="${JOBS:-4}"
dry_run=0
qmake_bin="${QMAKE:-}"

usage() {
  cat <<'EOF'
Usage: zsh ./build/scripts/build_macos.sh [--dry-run] [--jobs N] [--build-root DIR] [--bin-root DIR] [--qmake PATH]

Compile x2t avec qmake puis prepare le runtime local macOS.
Le runtime final est genere a la racine du workspace dans output/macos-arm64/runtime.
EOF
}

resolve_path() {
  local value="$1"
  if [[ "$value" != /* ]]; then
    value="$workspace_root/$value"
  fi
  printf '%s\n' "$value"
}

while (( $# > 0 )); do
  case "$1" in
    -n|--dry-run)
      dry_run=1
      ;;
    --jobs)
      shift
      [[ $# -gt 0 ]] || { echo "Option --jobs incomplete." >&2; exit 1; }
      jobs="$1"
      ;;
    --build-root)
      shift
      [[ $# -gt 0 ]] || { echo "Option --build-root incomplete." >&2; exit 1; }
      build_root="$1"
      ;;
    --bin-root)
      shift
      [[ $# -gt 0 ]] || { echo "Option --bin-root incomplete." >&2; exit 1; }
      bin_root="$1"
      ;;
    --qmake)
      shift
      [[ $# -gt 0 ]] || { echo "Option --qmake incomplete." >&2; exit 1; }
      qmake_bin="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Option inconnue: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

build_root=$(resolve_path "$build_root")
bin_root=$(resolve_path "$bin_root")

[[ -f "$qt_project" ]] || { echo "Projet Qt introuvable: $qt_project" >&2; exit 1; }
[[ -x "$runtime_script" ]] || { echo "Script runtime introuvable ou non executable: $runtime_script" >&2; exit 1; }

if [[ -z "$qmake_bin" ]]; then
  if command -v qmake >/dev/null 2>&1; then
    qmake_bin=$(command -v qmake)
  elif command -v qmake6 >/dev/null 2>&1; then
    qmake_bin=$(command -v qmake6)
  fi
fi

if (( dry_run )); then
  qmake_command="${qmake_bin:-qmake}"
  echo "[dry-run] qmake: ${qmake_bin:-qmake|qmake6}"
  echo "[dry-run] projet: $qt_project"
  echo "[dry-run] build root: $build_root"
  echo "[dry-run] bin root: $bin_root"
  echo "[dry-run] commandes:"
  echo "[dry-run]   mkdir -p \"$build_root\" \"$bin_root\""
  echo "[dry-run]   cd \"$build_root\" && $qmake_command -o Makefile \"$qt_project\""
  echo "[dry-run]   cd \"$build_root\" && make -j$jobs"
  echo "[dry-run]   cp <x2t executable> \"$bin_root/x2t\""
  echo "[dry-run]   zsh \"$runtime_script\""
  exit 0
fi

[[ -n "$qmake_bin" ]] || { echo "qmake introuvable. Installe Qt ou passe --qmake /chemin/vers/qmake." >&2; exit 1; }

rm -rf "$build_root"
mkdir -p "$build_root" "$bin_root"

pushd "$build_root" >/dev/null
"$qmake_bin" -o Makefile "$qt_project"
make -j"$jobs"

binary=$(find "$build_root" -type f -perm -111 -name x2t | head -n 1 || true)
[[ -n "$binary" ]] || { echo "Binaire x2t introuvable apres compilation." >&2; exit 1; }

cp "$binary" "$bin_root/x2t"
popd >/dev/null

zsh "$runtime_script"

echo "$bin_root/x2t"
echo "$workspace_root/output/macos-arm64/runtime"