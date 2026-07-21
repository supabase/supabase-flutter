#!/usr/bin/env bash
set -euo pipefail

target="$1"

examples=(database_crud passkeys)
defines=(
  "--dart-define=SUPABASE_URL=${SUPABASE_URL}"
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}"
)

if [ "${target}" = "web" ]; then
  chromedriver --port=4444 &
  chromedriver_pid=$!
  trap 'kill "${chromedriver_pid}" 2>/dev/null || true' EXIT
fi

for example in "${examples[@]}"; do
  echo "::group::${example} (${target})"
  pushd "examples/${example}" >/dev/null

  case "${target}" in
    web)
      mkdir -p test_driver
      cat > test_driver/integration_test.dart <<'DART'
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
DART
      for test_file in integration_test/*_test.dart; do
        flutter drive \
          --driver=test_driver/integration_test.dart \
          --target="${test_file}" \
          -d web-server \
          --browser-name=chrome \
          --headless \
          "${defines[@]}"
      done
      ;;
    linux)
      xvfb-run -a flutter test integration_test -d linux "${defines[@]}"
      ;;
    macos)
      flutter test integration_test -d macos "${defines[@]}"
      ;;
    windows)
      flutter test integration_test -d windows "${defines[@]}"
      ;;
    android)
      flutter test integration_test "${defines[@]}"
      ;;
    ios)
      flutter test integration_test -d "${IOS_DEVICE}" "${defines[@]}"
      ;;
    *)
      echo "Unknown target: ${target}" >&2
      exit 1
      ;;
  esac

  popd >/dev/null
  echo "::endgroup::"
done
