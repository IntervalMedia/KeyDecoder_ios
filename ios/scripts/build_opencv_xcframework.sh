#!/usr/bin/env bash
set -euo pipefail

readonly version="4.10.0"
readonly source_sha256="b2171af5be6b26f7a06b1229948bbb2bdaa74fcf5cd097e0af6378fce50a6eb9"
readonly cache_root="${HOME}/Library/Caches/keydecoder/opencv-${version}"
readonly source_archive="${cache_root}/opencv-${version}.tar.gz"
readonly source_dir="${cache_root}/opencv-${version}"
readonly build_dir="${cache_root}/build"
readonly framework_dir="$(cd "$(dirname "$0")/.." && pwd)/native_cv/Frameworks/opencv2.xcframework"

verify_framework() {
  python3 - "$1" <<'PY'
import pathlib
import plistlib
import subprocess
import sys

framework = pathlib.Path(sys.argv[1])
with (framework / "Info.plist").open("rb") as file:
    info = plistlib.load(file)

libraries = {
    (library["SupportedPlatform"], library.get("SupportedPlatformVariant")): library
    for library in info["AvailableLibraries"]
}
for key, required_architectures in (
    (("ios", None), {"arm64"}),
    (("ios", "simulator"), {"arm64", "x86_64"}),
):
    library = libraries.get(key)
    if library is None or not required_architectures.issubset(
        set(library["SupportedArchitectures"])
    ):
        sys.exit(1)
    binary = framework / library["LibraryIdentifier"] / library["LibraryPath"] / "opencv2"
    architectures = set(
        subprocess.check_output(["xcrun", "lipo", "-archs", str(binary)], text=True).split()
    )
    if not required_architectures.issubset(architectures):
        sys.exit(1)

headers = framework / libraries[("ios", "simulator")]["LibraryIdentifier"] / "opencv2.framework/Headers/core/version.hpp"
if not headers.is_file():
    sys.exit(1)
version = headers.read_text()
if any(value not in version for value in (
    "CV_VERSION_MAJOR    4",
    "CV_VERSION_MINOR    10",
    "CV_VERSION_REVISION 0",
)):
    sys.exit(1)
PY
}

if verify_framework "$framework_dir" 2>/dev/null; then
  echo "Using cached OpenCV ${version} XCFramework at ${framework_dir}"
  exit 0
fi

mkdir -p "$cache_root"
if [[ ! -f "$source_archive" ]]; then
  archive_download="${source_archive}.tmp"
  curl --fail --location --silent --show-error \
    "https://github.com/opencv/opencv/archive/refs/tags/${version}.tar.gz" \
    --output "$archive_download"
  echo "${source_sha256}  ${archive_download}" | shasum --check --status || {
    echo "OpenCV ${version} source archive checksum mismatch" >&2
    exit 1
  }
  mv "$archive_download" "$source_archive"
fi
echo "${source_sha256}  ${source_archive}" | shasum --check --status || {
  echo "OpenCV ${version} source archive checksum mismatch" >&2
  exit 1
}

if [[ ! -f "${source_dir}/CMakeLists.txt" ]]; then
  rm -rf "$source_dir"
  mkdir -p "$source_dir"
  tar -xzf "$source_archive" --strip-components=1 -C "$source_dir"
fi

python3 "$source_dir/platforms/apple/build_xcframework.py" \
  --out "$build_dir" \
  --iphoneos_archs arm64 \
  --iphonesimulator_archs arm64,x86_64 \
  --build_only_specified_archs \
  --without dnn \
  --without gapi \
  --without highgui \
  --without java \
  --without js \
  --without ml \
  --without objdetect \
  --without objc \
  --without photo \
  --without python \
  --without stitching \
  --without ts \
  --without video \
  --without videoio \
  --without world \
  --iphoneos_deployment_target 15.0 \
  --disable-bitcode

verify_framework "${build_dir}/opencv2.xcframework" || {
  echo "OpenCV XCFramework is missing required iOS device or simulator architectures" >&2
  exit 1
}

mkdir -p "$(dirname "$framework_dir")"
rm -rf "$framework_dir"
ditto "${build_dir}/opencv2.xcframework" "$framework_dir"
verify_framework "$framework_dir"
