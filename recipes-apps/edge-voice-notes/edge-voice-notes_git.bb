SUMMARY = "Offline voice notes: crash-safe queue, whisper.cpp transcription, llama.cpp summary"
HOMEPAGE = "https://github.com/rromero-emb/edge-voice-notes"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=afdf40d68ef6f7db1a4d2955d151b046"

SRC_URI = "git://github.com/rromero-emb/edge-voice-notes.git;protocol=https;branch=main"
SRCREV = "5e1c6dd51b27927e0182acc7b9f2a92bde4871cb"
PV = "0.1.0+git"
S = "${WORKDIR}/git"

inherit python_setuptools_build_meta

# stdlib only; these are the modules it imports (checked with grep in the repo)
RDEPENDS:${PN} += "\
    python3-core python3-json python3-logging python3-sqlite3 python3-crypt \
    python3-netclient python3-io python3-tomllib python3-audio \
"
# alsa-utils-aplay ships arecord, used by the recorder; whisper.cpp/llama.cpp come from their own recipes (not in this layer yet)
RRECOMMENDS:${PN} += "alsa-utils-aplay"
