#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

SHERPA_VERSION="1.12.36"
ONNXRUNTIME_VERSION="1.23.2"
FRAMEWORK_DIR="Frameworks"

SHERPA_ARCHIVE="sherpa-onnx-v${SHERPA_VERSION}-macos-xcframework-static.tar.bz2"
SHERPA_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/v${SHERPA_VERSION}/${SHERPA_ARCHIVE}"

ORT_ZIP="onnxruntime-osx-universal2-static_lib-${ONNXRUNTIME_VERSION}.zip"
ORT_URL="https://github.com/csukuangfj/onnxruntime-libs/releases/download/v${ONNXRUNTIME_VERSION}/${ORT_ZIP}"

mkdir -p "${FRAMEWORK_DIR}"

# --- sherpa-onnx xcframework ---
if [ -d "${FRAMEWORK_DIR}/sherpa-onnx.xcframework" ]; then
    echo "sherpa-onnx xcframework already exists, skipping download."
else
    echo "Downloading sherpa-onnx v${SHERPA_VERSION} xcframework..."
    curl -SL "${SHERPA_URL}" -o "${FRAMEWORK_DIR}/${SHERPA_ARCHIVE}"
    echo "Extracting sherpa-onnx..."
    cd "${FRAMEWORK_DIR}"
    tar xjf "${SHERPA_ARCHIVE}"
    rm "${SHERPA_ARCHIVE}"

    # Move xcframework out of versioned subdirectory
    SUBDIR="sherpa-onnx-v${SHERPA_VERSION}-macos-xcframework-static"
    if [ -d "${SUBDIR}/sherpa-onnx.xcframework" ]; then
        mv "${SUBDIR}/sherpa-onnx.xcframework" .
        rm -rf "${SUBDIR}"
    fi
    cd ..
    echo "Done: ${FRAMEWORK_DIR}/sherpa-onnx.xcframework"
fi

# --- onnxruntime static library ---
if [ -f "${FRAMEWORK_DIR}/libonnxruntime.a" ]; then
    echo "onnxruntime static library already exists, skipping download."
else
    echo "Downloading onnxruntime v${ONNXRUNTIME_VERSION} static library..."
    curl -SL "${ORT_URL}" -o "${FRAMEWORK_DIR}/${ORT_ZIP}"
    echo "Extracting onnxruntime..."
    cd "${FRAMEWORK_DIR}"
    unzip -o "${ORT_ZIP}"
    rm "${ORT_ZIP}"

    # Move libonnxruntime.a out of versioned subdirectory
    ORT_SUBDIR="onnxruntime-osx-universal2-static_lib-${ONNXRUNTIME_VERSION}"
    if [ -d "${ORT_SUBDIR}/lib" ]; then
        mv "${ORT_SUBDIR}/lib/libonnxruntime.a" .
        rm -rf "${ORT_SUBDIR}"
    fi
    cd ..
    echo "Done: ${FRAMEWORK_DIR}/libonnxruntime.a"
fi

echo ""
echo "Frameworks directory contents:"
ls -lh "${FRAMEWORK_DIR}/"
