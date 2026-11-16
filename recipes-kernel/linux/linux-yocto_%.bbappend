FILESEXTRAPATHS:prepend:rromero := "${THISDIR}/files:"
# SocketCAN core, raw sockets and the virtual CAN driver for j1939-edge-logger tests
SRC_URI:append:rromero = " file://can.cfg"
