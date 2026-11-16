SUMMARY = "Passive J1939 logger for embedded Linux (SocketCAN, TP reassembly, power-cut-safe journal)"
HOMEPAGE = "https://github.com/rromero-emb/j1939-edge-logger"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=afdf40d68ef6f7db1a4d2955d151b046"

SRC_URI = "git://github.com/rromero-emb/j1939-edge-logger.git;protocol=https;branch=main"
SRCREV = "428b21b8bd331d39bb95c9a7b54105bb83feb6d2"
PV = "0.1+git"
S = "${WORKDIR}/git"

inherit cmake

# unit tests run in the project's own CI; FetchContent cannot download inside bitbake
EXTRA_OECMAKE = "-DBUILD_TESTING=OFF"

FILES:${PN} += "${datadir}/j1939-edge-logger"
