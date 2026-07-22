#!/usr/bin/env bash
# Runs the examples launcher: boots the local Supabase stack and runs the
# example you pick. Any arguments are forwarded to `flutter run`.
set -euo pipefail

cd "$(dirname "$0")/launcher"
dart pub get
exec dart run bin/examples_launcher.dart "$@"
