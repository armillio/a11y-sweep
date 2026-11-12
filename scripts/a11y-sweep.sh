#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'Usage: a11y-sweep.sh (--project path.xcodeproj | --workspace path.xcworkspace) --scheme name --only-testing Target/Class[/method] [--device iphone|ipad|both (default: iphone)] [--looks a,b] [--runtime id] [--output dir]' >&2
  exit 2
}

project='' workspace='' scheme='' only_testing='' device='iphone' looks=''
runtime='com.apple.CoreSimulator.SimRuntime.iOS-18-6'
output=''
while (($#)); do
  case "$1" in
    --project|--workspace|--scheme|--only-testing|--device|--looks|--runtime|--output)
      (($# >= 2)) || usage
      case "$1" in
        --project) project=$2 ;;
        --workspace) workspace=$2 ;;
        --scheme) scheme=$2 ;;
        --only-testing) only_testing=$2 ;;
        --device) device=$2 ;;
        --looks) looks=$2 ;;
        --runtime) runtime=$2 ;;
        --output) output=$2 ;;
      esac
      shift 2 ;;
    *) usage ;;
  esac
done

[[ -n $scheme && -n $only_testing ]] || usage
[[ -n $project && -z $workspace || -z $project && -n $workspace ]] || usage
[[ $device == iphone || $device == ipad || $device == both ]] || usage
[[ -n $output ]] || output=".a11y-sweep/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$output"
output=$(cd "$output" && pwd -P)

created_simulators=()
derived_data=()
active_pid=''
# Invoked by the EXIT trap below.
# shellcheck disable=SC2329
cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [[ -n $active_pid ]]; then
    kill "$active_pid" 2>/dev/null || true
    wait "$active_pid" 2>/dev/null || true
  fi
  for udid in ${created_simulators[@]+"${created_simulators[@]}"}; do
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
  done
  for dir in ${derived_data[@]+"${derived_data[@]}"}; do
    rm -rf -- "$dir"
  done
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ -n $project ]]; then
  location=(-project "$project")
else
  location=(-workspace "$workspace")
fi

ipad_types=()
if [[ $device == ipad || $device == both ]]; then
  while IFS= read -r type; do ipad_types+=("$type"); done < <(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
types = json.load(sys.stdin)["devicetypes"]
for item in reversed(types):
    if item.get("name", "").startswith("iPad"):
        print(item["identifier"])
')
fi

create_simulator() {
  local kind=$1 group=$2 name type udid
  name="a11y-sweep-${kind}-${group}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  if [[ $kind == iphone ]]; then
    type='com.apple.CoreSimulator.SimDeviceType.iPhone-16'
    udid=$(xcrun simctl create "$name" "$type" "$runtime") || return 1
  else
    type='com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M3'
    if ! udid=$(xcrun simctl create "$name" "$type" "$runtime" 2>/dev/null); then
      udid=''
      for type in ${ipad_types[@]+"${ipad_types[@]}"}; do
        if udid=$(xcrun simctl create "$name" "$type" "$runtime" 2>/dev/null); then
          break
        fi
      done
      [[ -n $udid ]] || return 1
    fi
  fi
  created_simulators+=("$udid")
  created_udid=$udid
}

devices=(iphone ipad)
if [[ $device != both ]]; then devices=("$device"); fi
groups=(none increase-contrast)
if [[ -n $looks ]]; then
  # Known presets have a fixed host setting. Custom names are tried in both groups.
  known_only=1
  wants_none=0
  wants_contrast=0
  IFS=',' read -r -a requested_looks <<< "$looks"
  for requested in ${requested_looks[@]+"${requested_looks[@]}"}; do
    requested=${requested//[[:space:]]/}
    case "$requested" in
      baseline|dark|largest-text|dark-largest-text|landscape|landscape-largest-text) wants_none=1 ;;
      increased-contrast|increased-contrast-dark) wants_contrast=1 ;;
      *) known_only=0 ;;
    esac
  done
  if ((known_only)); then
    groups=()
    if ((wants_none)); then groups+=(none); fi
    if ((wants_contrast)); then groups+=(increase-contrast); fi
  fi
fi
failed=0
for kind in ${devices[@]+"${devices[@]}"}; do
  for group in ${groups[@]+"${groups[@]}"}; do
    if ! create_simulator "$kind" "$group"; then
      echo "Could not create ${kind} simulator for ${group}" >&2
      failed=1
      continue
    fi
    udid=$created_udid
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b
    if [[ $group == increase-contrast ]]; then
      xcrun simctl ui "$udid" increase_contrast enabled
    fi
    dd=$(mktemp -d)
    derived_data+=("$dd")
    touch "$dd/run-start"
    result="$output/${kind}-${group}.xcresult"
    environment=("TEST_RUNNER_A11Y_SWEEP_OUTPUT=$output" "TEST_RUNNER_A11Y_SWEEP_HOST_SETTING=$group")
    if [[ -n $looks ]]; then environment+=("TEST_RUNNER_A11Y_SWEEP_LOOKS=$looks"); fi
    env ${environment[@]+"${environment[@]}"} xcodebuild test ${location[@]+"${location[@]}"} -scheme "$scheme" \
      -destination "platform=iOS Simulator,id=$udid" -only-testing:"$only_testing" \
      -derivedDataPath "$dd" -resultBundlePath "$result" CODE_SIGNING_ALLOWED=NO &
    active_pid=$!
    if wait "$active_pid"; then
      :
    else
      echo "xcodebuild failed for ${kind} ${group}" >&2
      failed=1
    fi
    active_pid=''
    new_summaries=$(find "$output" -maxdepth 1 -name "${kind}-*-summary.txt" -newer "$dd/run-start" | wc -l | tr -d ' ')
    if ((new_summaries == 0)); then
      echo "No summary produced for ${kind} ${group}" >&2
      failed=1
    fi
  done
done

# Each requested look belongs to one host-setting group, so after all groups ran every
# requested look must have a summary per device. A typo or a silently skipped look fails.
if [[ -n $looks ]]; then
  IFS=',' read -r -a requested_looks <<< "$looks"
  for kind in ${devices[@]+"${devices[@]}"}; do
    for look in ${requested_looks[@]+"${requested_looks[@]}"}; do
      if [[ ! -f "$output/${kind}-${look}-summary.txt" ]]; then
        echo "No summary for requested look ${look} on ${kind}" >&2
        failed=1
      fi
    done
  done
fi

for summary in "$output"/*-summary.txt; do
  if [[ -f $summary ]]; then cat "$summary"; fi
done
printf 'Sweep output: %s\n' "$output"
exit "$failed"
