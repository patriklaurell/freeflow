#!/bin/bash
set -euo pipefail
bin_dir=$1
resources=$2
checkouts=$3
metal_bundle="$bin_dir/mlx-swift_Cmlx.bundle"
if [[ ! -s "$metal_bundle/Contents/Resources/default.metallib" ]]; then
    echo 'Missing MLX Metal library. Install the Xcode Metal toolchain and build with Swift Build; do not ship a native-build-only binary.' >&2
    exit 1
fi
mkdir -p "$resources"
for name in mlx-swift_Cmlx swift-transformers_Hub swift-crypto_Crypto; do
    bundle="$bin_dir/$name.bundle"
    if [[ ! -d "$bundle" ]]; then
        echo "Required resource bundle is missing: $name" >&2
        exit 1
    fi
done
for name in mlx-swift_Cmlx swift-transformers_Hub swift-crypto_Crypto; do
    ditto "$bin_dir/$name.bundle" "$resources/$name.bundle"
done
# Static dependencies retain their license notices in the standalone app.
mkdir -p "$resources/Licenses"
for dependency in "$checkouts"/*; do
    [[ -d "$dependency" ]] || continue
    name=$(basename "$dependency")
    for notice in LICENSE LICENSE.txt LICENSE.md COPYING NOTICE; do
        if [[ -f "$dependency/$notice" ]]; then
            mkdir -p "$resources/Licenses/$name"
            cp "$dependency/$notice" "$resources/Licenses/$name/$notice"
        fi
    done
done
for dependency in mlx mlx-c; do
    if [[ -f "$checkouts/mlx-swift/Source/Cmlx/$dependency/LICENSE" ]]; then
        cp "$checkouts/mlx-swift/Source/Cmlx/$dependency/LICENSE" "$resources/Licenses/mlx-swift/$dependency-LICENSE"
    fi
done
if [[ -f LICENSE ]]; then cp LICENSE "$resources/Licenses/FreeFlow-LICENSE"; fi
for relative in metal-cpp/LICENSE.txt json/LICENSE.MIT fmt/LICENSE mlx/ACKNOWLEDGMENTS.md mlx-c/ACKNOWLEDGMENTS.md; do
    source="$checkouts/mlx-swift/Source/Cmlx/$relative"
    if [[ -f "$source" ]]; then
        destination="$resources/Licenses/mlx-swift/vendor/$relative"
        mkdir -p "$(dirname "$destination")"
        cp "$source" "$destination"
    fi
done
